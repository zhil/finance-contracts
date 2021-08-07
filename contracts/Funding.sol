//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./lib/PaymentRecipientUpgradable.sol";

import "hardhat/console.sol";

contract Funding is
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    BancorFormula,
    PaymentRecipientUpgradable
{
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    string public constant name = "Flair Public Funding Pool";

    string public constant version = "0.1";

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ORCHESTRATOR_ROLE = keccak256("ORCHESTRATOR_ROLE");

    struct Contribution {
        address investor;
        bytes32 campaignHash;
        uint256 amount;
        uint256 filled;
        uint256 registeredAt;
        uint256 canceledAt;
    }

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address private _token;
    uint32 private _rewardRatio;
    uint256 private _totalContribution;
    uint256 private _totalRewarded;

    /* Contributions by incremental ID. */
    Contribution[] public contributions;

    /* Contributions, by hash. */
    mapping(bytes32 => uint256[]) public contributionsByHash;

    /* Funding options, by hash. */
    mapping(bytes32 => uint256[8]) public optionsByHash;

    /* Funding hashes, by beneficiary address. */
    mapping(address => bytes32[]) public hashesByBeneficiary;

    /* Total filled amounts, by beneficiary address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public filledTotalByBeneficiaryAndHash;

    /* Released times, by beneficiary address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public releasedTimes;

    /* EVENTS */

    event ContributionRegistered(
        address indexed beneficiary,
        bytes32 indexed campaignHash,
        address indexed investor,
        uint256 filled,
        uint256 amount,
        uint256 contributionID
    );

    event ContributionRefunded(
        address indexed beneficiary,
        bytes32 indexed campaignHash,
        address indexed investor,
        uint256 unfilled,
        uint256 remainderAmount,
        uint256 contributionID
    );

    /* MODIFIERS */

    modifier isGovernor() {
        require(hasRole(GOVERNOR_ROLE, _msgSender()), "TOKEN/NOT_GOVERNOR");
        _;
    }

    /* FUNCTIONS */

    function initialize(address token, uint32 rewardRatio) public initializer {
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _msgSender());

        _token = token;
        _rewardRatio = rewardRatio;

        // Bancor formula requires initial variables to correctly calculate rewards
        _totalContribution = 1 ether;
        _totalRewarded = 1000 ether;
    }

    /* ADMIN */

    function setToken(address newAddress) public isGovernor() {
        _token = newAddress;
    }

    function setRewardRatio(uint32 newRatio) public isGovernor() {
        _rewardRatio = newRatio;
    }

    /* INTERNAL */

    function _calculateReleasedAmountUntil(
        Contribution memory contribution,
        uint256 checkpoint,
        bytes32 hash
    ) internal view returns (uint256) {
        uint256[8] memory options = optionsByHash[hash];
        uint256 effectiveCheckpoint =
            contribution.canceledAt > 0
                ? (contribution.canceledAt < checkpoint ? contribution.canceledAt : checkpoint)
                : checkpoint;

        if (effectiveCheckpoint < contribution.registeredAt) {
            return 0;
        }

        uint256 upfrontPayment =
            options[0] > 0 /* upfrontPaymentPercentage */
                ? _calculatePercentage(options[0], contribution.amount)
                : 0;
        uint256 total = upfrontPayment;

        if (
            effectiveCheckpoint < contribution.registeredAt + options[1] /* cliffPeriod */
        ) {
            return total;
        }

        uint256 cliffPayment =
            options[2] > 0 /* cliffPayment */
                ? _calculatePercentage(options[2], contribution.amount)
                : 0;
        total += cliffPayment;

        uint256 vestingPeriod = options[3];
        uint256 vestingTotalAmount = contribution.amount - upfrontPayment - cliffPayment;

        uint256 startOfVesting = (contribution.registeredAt + options[1]); /* cliffPeriod */
        uint256 vestedDuration = startOfVesting > effectiveCheckpoint ? 0 : effectiveCheckpoint - startOfVesting;
        if (vestedDuration > vestingPeriod) {
            vestedDuration = vestingPeriod;
        }

        uint256 vestedAmount =
            BancorFormula._saleTargetAmount(
                vestingPeriod,
                vestingTotalAmount,
                uint32(options[4]), /* vestingRatio */
                vestedDuration
            );

        return total + vestedAmount;
    }

    function _calculatePercentage(uint256 percent, uint256 total) private pure returns (uint256) {
        return (percent * total) / INVERSE_BASIS_POINT;
    }

    function _reward(address to, uint256 contributionAmount) internal virtual {
        uint256 reward =
            BancorFormula._purchaseTargetAmount(_totalRewarded, _totalContribution, _rewardRatio, contributionAmount);
        _totalRewarded += reward;
        _totalContribution += contributionAmount;

        (bool success, ) = _token.call(abi.encodeWithSignature("mint(address,uint256)", to, reward));

        require(success, "FUNDING/REWARD_FAILED");
    }

    /* PUBLIC */

    function totalContributionsByHash(bytes32 campaignHash) public view returns (uint256) {
        return contributionsByHash[campaignHash].length;
    }

    function registerContribution(
        address beneficiary,
        bytes32 campaignHash,
        uint256[8] memory fundingOptions,
        address investor,
        uint256 filled,
        uint256 amount
    ) public payable virtual nonReentrant {
        /* CHECKS */
        require(hasRole(ORCHESTRATOR_ROLE, _msgSender()), "FUNDING/NOT_ORCHESTRATOR");
        require(filled > 0, "FUNDING/INVALID_FILLED");

        /* EFFECTS */
        if (filledTotalByBeneficiaryAndHash[beneficiary][campaignHash] < 1) {
            hashesByBeneficiary[beneficiary].push(campaignHash);
            optionsByHash[campaignHash] = fundingOptions;
        }

        contributions.push(Contribution(investor, campaignHash, amount, filled, block.timestamp, 0));
        uint256 contributionId = contributions.length - 1;

        contributionsByHash[campaignHash].push(contributionId);
        filledTotalByBeneficiaryAndHash[beneficiary][campaignHash] += filled;

        /* LOG */
        emit ContributionRegistered(beneficiary, campaignHash, investor, filled, amount, contributionId);
    }

    function refundContribution(
        address beneficiary,
        bytes32 campaignHash,
        address investor,
        uint256 unfilled,
        uint256 contributionId
    ) public payable virtual nonReentrant {
        /* CHECKS */
        require(hasRole(ORCHESTRATOR_ROLE, _msgSender()), "FUNDING/NOT_ORCHESTRATOR");
        require(contributions[contributionId].registeredAt > 0, "FUNDING/INVALID_CONTRIBUTION");

        require(
            unfilled > 0 && filledTotalByBeneficiaryAndHash[beneficiary][campaignHash] >= unfilled,
            "FUNDING/INVALID_UNFILLED"
        );
        require(contributions[contributionId].canceledAt == 0, "FUNDING/ALREADY_CANCELED");
        require(contributions[contributionId].investor == investor, "FUNDING/NOT_INVESTOR");
        require(contributions[contributionId].filled == unfilled, "FUNDING/FILL_MISMATCH");

        uint256 toBeReleased = _calculateReleasedAmountUntil(contributions[contributionId], block.timestamp, campaignHash);

        require(toBeReleased < contributions[contributionId].amount, "FUNDING/NOTHING_TO_REFUND");

        uint256 remainderAmount = contributions[contributionId].amount - toBeReleased;

        /* EFFECTS */
        contributions[contributionId].canceledAt = block.timestamp;
        filledTotalByBeneficiaryAndHash[beneficiary][campaignHash] -= unfilled;

        /* INTERACTIONS */
        payable(investor).sendValue(remainderAmount);

        /* LOG */
        emit ContributionRefunded(beneficiary, campaignHash, investor, unfilled, remainderAmount, contributionId);
    }

    function releaseAllToBeneficiary() public virtual nonReentrant {
        address beneficiary = _msgSender();

        /* EFFECTS */
        uint256 totalToBeReleased;

        for (uint256 i = 0; i < hashesByBeneficiary[beneficiary].length; i++) {
            bytes32 hash = hashesByBeneficiary[beneficiary][i];
            totalToBeReleased += _prepareReleaseToBeneficiaryByHash(beneficiary, hash);
        }

        /* INTERACTIONS */
        require(totalToBeReleased > 0, "FUNDING/NOTHING_TO_RELEASE");
        payable(beneficiary).sendValue(totalToBeReleased);
        _reward(beneficiary, totalToBeReleased);
    }

    function releaseToBeneficiaryByHash(bytes32 hash) public virtual nonReentrant {
        address beneficiary = _msgSender();
        uint256 now = block.timestamp;

        uint256 totalToBeReleased = _prepareReleaseToBeneficiaryByHash(beneficiary, hash);
        require(totalToBeReleased > 0, "FUNDING/NOTHING_TO_RELEASE");

        payable(beneficiary).sendValue(totalToBeReleased);
        _reward(beneficiary, totalToBeReleased);
    }

    function _prepareReleaseToBeneficiaryByHash(address beneficiary, bytes32 hash)
        internal
        returns (uint256 toBeReleased)
    {
        uint256 now = block.timestamp;
        uint256 lastRelease = releasedTimes[beneficiary][hash];

        require(lastRelease <= now - 1 hours, "FUNDING/RELEASE_HOURLY_LIMIT");

        toBeReleased = 0;

        for (uint256 j = 0; j < contributionsByHash[hash].length; j++) {
            toBeReleased +=
                _calculateReleasedAmountUntil(contributions[contributionsByHash[hash][j]], now, hash) -
                _calculateReleasedAmountUntil(contributions[contributionsByHash[hash][j]], lastRelease, hash);
        }

        releasedTimes[beneficiary][hash] = now;
    }
}
