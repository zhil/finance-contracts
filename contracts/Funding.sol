//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

import "./lib/BancorFormula.sol";
import "./Token.sol";

contract Funding is
    BancorFormula,
    ReentrancyGuardUpgradeable
{
    using AddressUpgradeable for address;
    using AddressUpgradeable for address payable;

    struct Investment {
        uint256 amount;
        uint256 time;
    }

    uint256 constant INVERSE_BASIS_POINT = 10000;

    address private _token;

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

    /* FUNCTIONS */

    function __Funding_init(address token) public initializer {
        __ReentrancyGuard_init_unchained();
        __Funding_init_unchained(token);
    }

    function __Funding_init_unchained(address token) public initializer {
        _token = token;
    }

    /* INTERNAL */

    function _registerInvestment(
        uint256 filled,
        bytes32 hash,
        uint256 requiredPayment,
        address beneficiary,
        uint256[8] memory fundingOptions
    ) internal virtual {
        if (filledAmountByBeneficiaryAndHash[beneficiary][hash] < 1) {
            hashesByBeneficiary[beneficiary].push(hash);
            optionsByHash[hash] = fundingOptions;
        }

        filledAmountByBeneficiaryAndHash[beneficiary][hash] += filled;
        investmentsByHash[hash].push(Investment(msg.value, block.timestamp));
    }

    function _calculateReleasedAmountUntil(Investment memory investment, uint256 checkpoint, bytes32 hash) internal view returns (uint256) {
        uint256[8] memory options = optionsByHash[hash];

        require(investment.time < checkpoint, "FUNDING/TOO_EARLY");

        uint256 upfrontPayment = options[0]/* upfrontPaymentPercentage */ > 0 ? _calculatePercentage(options[0], investment.amount) : 0;
        uint256 total = upfrontPayment;

        if (checkpoint < investment.time + options[1]/* cliffPeriod */) {
            return total;
        }

        uint256 cliffPayment = options[2]/* cliffPayment */ > 0 ? _calculatePercentage(options[2], investment.amount) : 0;
        total += cliffPayment;

        uint256 endOfVesting = (investment.time + options[1]/* cliffPeriod */ + options[3]/* vestingPeriod */);
        uint256 vestedDuration = endOfVesting < checkpoint ? options[3] : endOfVesting - checkpoint;

        uint256 vestingPeriod = options[3];
        uint256 vestingTotalAmount = investment.amount - upfrontPayment - cliffPayment;

        return saleTargetAmount(
            vestingPeriod,
            vestingTotalAmount,
            uint32(options[4])/* vestingRatio */,
            vestedDuration
        );
    }

    function _calculatePercentage(uint256 percent, uint256 total) private pure returns (uint256) {
        return (percent * total) / INVERSE_BASIS_POINT;
    }

    /* PUBLIC */

    function releaseAllToBeneficiary() public virtual nonReentrant {
        address beneficiary = msg.sender;
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
        Token(_token).reward(beneficiary, toBeReleased);
    }
}
