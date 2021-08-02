//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./lib/PaymentRecipientUpgradable.sol";

import "hardhat/console.sol";

contract Funding is ContextUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, BancorFormula, PaymentRecipientUpgradable {
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant ORCHESTRATOR_ROLE = keccak256("ORCHESTRATOR_ROLE");

    struct Investment {
        uint256 amount;
        uint256 time;
    }

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address private _token;
    uint32 private _rewardRatio;
    uint256 private _totalContribution;
    uint256 private _totalRewarded;

    /* Funding filled amount, by beneficiary address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public filledAmountByBeneficiaryAndHash;

    /* Funding options, by hash. */
    mapping(bytes32 => uint256[8]) public optionsByHash;

    /* Funding hashes, by beneficiary address. */
    mapping(address => bytes32[]) public hashesByBeneficiary;

    /* Funding investments, by hash. */
    mapping(bytes32 => Investment[]) public investmentsByHash;

    /* Released times, by beneficiary address. */
    mapping(address => uint256) public releasedTimes;

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
        Investment memory investment,
        uint256 checkpoint,
        bytes32 hash
    ) internal view returns (uint256) {
        uint256[8] memory options = optionsByHash[hash];

        require(investment.time < checkpoint, "FUNDING/TOO_EARLY");

        uint256 upfrontPayment =
            options[0] > 0 /* upfrontPaymentPercentage */
                ? _calculatePercentage(options[0], investment.amount)
                : 0;
        uint256 total = upfrontPayment;

        if (
            checkpoint < investment.time + options[1] /* cliffPeriod */
        ) {
            return total;
        }

        uint256 cliffPayment =
            options[2] > 0 /* cliffPayment */
                ? _calculatePercentage(options[2], investment.amount)
                : 0;
        total += cliffPayment;

        uint256 endOfVesting =
            (investment.time +
                options[1] + /* cliffPeriod */
                options[3]); /* vestingPeriod */
        uint256 vestedDuration = endOfVesting < checkpoint ? options[3] : endOfVesting - checkpoint;

        uint256 vestingPeriod = options[3];
        uint256 vestingTotalAmount = investment.amount - upfrontPayment - cliffPayment;

        return
            BancorFormula._saleTargetAmount(
                vestingPeriod,
                vestingTotalAmount,
                uint32(options[4]), /* vestingRatio */
                vestedDuration
            );
    }

    function _calculatePercentage(uint256 percent, uint256 total) private pure returns (uint256) {
        return (percent * total) / INVERSE_BASIS_POINT;
    }

    function _reward(address to, uint256 contributionAmount) internal virtual {
        uint256 reward =
            BancorFormula._purchaseTargetAmount(_totalRewarded, _totalContribution, _rewardRatio, contributionAmount);
        _totalRewarded += reward;
        _totalContribution += contributionAmount;

        _token.call(abi.encodeWithSignature("_mint(address,uint256)", to, reward));
    }

    /* PUBLIC */

    function registerInvestment(
        uint256 filled,
        bytes32 hash,
        uint256 requiredPayment,
        address beneficiary,
        uint256[8] memory fundingOptions
    ) public payable virtual {
        require(hasRole(ORCHESTRATOR_ROLE, _msgSender()), "FUNDING/NOT_ORCHESTRATOR");

        if (filledAmountByBeneficiaryAndHash[beneficiary][hash] < 1) {
            hashesByBeneficiary[beneficiary].push(hash);
            optionsByHash[hash] = fundingOptions;
        }

        filledAmountByBeneficiaryAndHash[beneficiary][hash] += filled;
        investmentsByHash[hash].push(Investment(msg.value, block.timestamp));
    }

    function releaseAllToBeneficiary() public virtual nonReentrant {
        address beneficiary = _msgSender();
        uint256 lastRelease = releasedTimes[beneficiary];
        uint256 now = block.timestamp;

        require(lastRelease <= now - 1 hours, "FUNDING/HOURLY_LIMIT");

        uint256 toBeReleased;

        for (uint256 i = 0; i < hashesByBeneficiary[beneficiary].length; i++) {
            bytes32 hash = hashesByBeneficiary[beneficiary][i];
            for (uint256 j = 0; j < investmentsByHash[hash].length; j++) {
                toBeReleased +=
                    _calculateReleasedAmountUntil(investmentsByHash[hash][j], now, hash) -
                    _calculateReleasedAmountUntil(investmentsByHash[hash][j], lastRelease, hash);
            }
        }

        releasedTimes[beneficiary] = now;

        payable(beneficiary).sendValue(toBeReleased);
        _reward(beneficiary, toBeReleased);
    }
}
