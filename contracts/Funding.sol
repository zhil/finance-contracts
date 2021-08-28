//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "hardhat/console.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./lib/PaymentRecipientUpgradable.sol";

contract Funding is
    ContextUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    BancorFormula,
    PaymentRecipientUpgradable
{
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    string public constant name = "Flair Common Funding Pool";

    string public constant version = "0.1";

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ORCHESTRATOR_ROLE = keccak256("ORCHESTRATOR_ROLE");

    struct Contribution {
        address investor;
        bytes32 offerHash;
        uint256 amount;
        uint256 filled;
        uint256 registeredAt;
        uint256 refundedAt;
    }

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address private _token;
    uint32 private _rewardRatio;
    uint256 private _totalContribution;
    uint256 private _totalRewarded;

    /* All contributions ever added to this funding pool. */
    Contribution[] public contributions;

    /* Contributions incremental ID. */
    CountersUpgradeable.Counter private _contributionIdTracker;

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
        bytes32 indexed offerHash,
        address indexed investor,
        uint256 filled,
        uint256 amount,
        uint256 contributionID
    );

    event ContributionRefunded(
        address indexed beneficiary,
        bytes32 indexed offerHash,
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
            contribution.refundedAt > 0
                ? (contribution.refundedAt < checkpoint ? contribution.refundedAt : checkpoint)
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

    function _prepareReleaseToBeneficiaryByHash(address beneficiary, bytes32 hash)
    internal
    returns (uint256 releasable)
    {
        uint256 now = block.timestamp;
        uint256 lastRelease = releasedTimes[beneficiary][hash];

        require(lastRelease <= now - 1 hours, "FUNDING/RELEASE_HOURLY_LIMIT");

        releasable = _calculateReleasableToBeneficiaryByHash(beneficiary, hash);

        releasedTimes[beneficiary][hash] = now;
    }

    function _calculateReleasableToBeneficiaryByHash(address beneficiary, bytes32 hash)
    internal
    view
    returns (uint256 releasable)
    {
        uint256 now = block.timestamp;
        uint256 lastRelease = releasedTimes[beneficiary][hash];

        releasable = 0;

        for (uint256 j = 0; j < contributionsByHash[hash].length; j++) {
            releasable +=
            _calculateReleasedAmountUntil(contributions[contributionsByHash[hash][j]], now, hash) -
            _calculateReleasedAmountUntil(contributions[contributionsByHash[hash][j]], lastRelease, hash);
        }
    }

    function _calculateReleasedToBeneficiaryByHash(address beneficiary, bytes32 hash)
    internal
    view
    returns (uint256 alreadyReleased)
    {
        uint256 now = block.timestamp;
        alreadyReleased = 0;

        for (uint256 j = 0; j < contributionsByHash[hash].length; j++) {
            alreadyReleased += _calculateReleasedAmountUntil(contributions[contributionsByHash[hash][j]], now, hash);
        }
    }

    /* PUBLIC */

    function totalContributionsByHash(bytes32 offerHash) public view returns (uint256) {
        return contributionsByHash[offerHash].length;
    }

    function registerContribution(
        address beneficiary,
        bytes32 offerHash,
        uint256[8] memory fundingOptions,
        address investor,
        uint256 filled,
        uint256 amount
    ) public payable virtual nonReentrant {
        /* CHECKS */
        require(hasRole(ORCHESTRATOR_ROLE, _msgSender()), "FUNDING/NOT_ORCHESTRATOR");
        require(filled > 0, "FUNDING/INVALID_FILLED");

        /* EFFECTS */
        if (filledTotalByBeneficiaryAndHash[beneficiary][offerHash] < 1) {
            hashesByBeneficiary[beneficiary].push(offerHash);
            optionsByHash[offerHash] = fundingOptions;
        }

        contributions.push(Contribution(investor, offerHash, amount, filled, block.timestamp, 0));
        uint256 contributionId = contributions.length - 1;

        contributionsByHash[offerHash].push(contributionId);
        filledTotalByBeneficiaryAndHash[beneficiary][offerHash] += filled;

        /* LOG */
        emit ContributionRegistered(beneficiary, offerHash, investor, filled, amount, contributionId);
    }

    function refundContribution(
        address beneficiary,
        bytes32 offerHash,
        address investor,
        uint256 unfilled,
        uint256 contributionId
    ) public payable virtual nonReentrant {
        /* CHECKS */
        require(hasRole(ORCHESTRATOR_ROLE, _msgSender()), "FUNDING/NOT_ORCHESTRATOR");
        require(contributions[contributionId].registeredAt > 0, "FUNDING/INVALID_CONTRIBUTION");

        require(
            unfilled > 0 && filledTotalByBeneficiaryAndHash[beneficiary][offerHash] >= unfilled,
            "FUNDING/INVALID_UNFILLED"
        );
        require(contributions[contributionId].refundedAt == 0, "FUNDING/ALREADY_CANCELED");
        require(contributions[contributionId].investor == investor, "FUNDING/NOT_INVESTOR");
        require(contributions[contributionId].filled == unfilled, "FUNDING/FILL_MISMATCH");

        uint256 alreadyReleased = _calculateReleasedAmountUntil(contributions[contributionId], block.timestamp, offerHash);

        require(alreadyReleased < contributions[contributionId].amount, "FUNDING/NOTHING_TO_REFUND");

        uint256 remainderAmount = contributions[contributionId].amount - alreadyReleased;

        /* EFFECTS */
        contributions[contributionId].refundedAt = block.timestamp;
        filledTotalByBeneficiaryAndHash[beneficiary][offerHash] -= unfilled;

        /* INTERACTIONS */
        payable(investor).sendValue(remainderAmount);

        /* LOG */
        emit ContributionRefunded(beneficiary, offerHash, investor, unfilled, remainderAmount, contributionId);
    }

    function calculateStatsByHashBatch(address beneficiary, bytes32[] memory hashes) public view returns (
        uint256 totalReleasable,
        uint256 totalAlreadyReleased,
        uint256 totalFilled
    ) {
        totalReleasable = 0;
        totalAlreadyReleased = 0;
        totalFilled = 0;

        for (uint256 i = 0; i < hashes.length; i++) {
            totalReleasable += _calculateReleasableToBeneficiaryByHash(beneficiary, hashes[i]);
            totalAlreadyReleased += _calculateReleasedToBeneficiaryByHash(beneficiary, hashes[i]);
            totalFilled += filledTotalByBeneficiaryAndHash[beneficiary][hashes[i]];
        }
    }

    function calculateStatsByBeneficiary(address beneficiary) public view returns (
        uint256 totalReleasable,
        uint256 totalAlreadyReleased,
        uint256 totalFilled
    ) {
        return calculateStatsByHashBatch(beneficiary, hashesByBeneficiary[beneficiary]);
    }

    function releaseAllToBeneficiary() public virtual nonReentrant {
        address beneficiary = _msgSender();

        /* EFFECTS */
        uint256 totalToBeReleased;

        for (uint256 i = 0; i < hashesByBeneficiary[beneficiary].length; i++) {
            totalToBeReleased += _prepareReleaseToBeneficiaryByHash(
                beneficiary,
                hashesByBeneficiary[beneficiary][i]
            );
        }

        /* INTERACTIONS */
        require(totalToBeReleased > 0, "FUNDING/NOTHING_TO_RELEASE");
        payable(beneficiary).sendValue(totalToBeReleased);
        _reward(beneficiary, totalToBeReleased);
    }

    function calculateReleasedAmountByContributionId(address beneficiary, uint256 contributionId)
    public
    view
    returns (uint256)
    {
        return _calculateReleasedAmountUntil(
            contributions[contributionId],
            block.timestamp,
            contributions[contributionId].offerHash
        );
    }

    function releaseToBeneficiaryByHash(bytes32 hash) public virtual nonReentrant {
        address beneficiary = _msgSender();
        uint256 now = block.timestamp;

        /* EFFECTS */
        uint256 totalReleasable = _prepareReleaseToBeneficiaryByHash(beneficiary, hash);
        require(totalReleasable > 0, "FUNDING/NOTHING_TO_RELEASE");

        /* INTERACTIONS */
        payable(beneficiary).sendValue(totalReleasable);
        _reward(beneficiary, totalReleasable);
    }
}
