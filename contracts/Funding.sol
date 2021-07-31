//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract Funding is
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    struct Investment {
        uint256 amount;
        address beneficiary;
        uint256[9] options;
    }

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _msgSender());
    }

    function _registerInvestment(
        uint256 investedAmount,
        address beneficiary,
        uint256[9] memory fundingOptions
    ) public virtual {
        require(msg.value >= investedAmount, "FUNDING/INSUFFICIENT_PAYMENT");

        // TODO Save individual investments in most efficient ways possible (both storage, and for withdrawal)
    }

    function withdraw() public virtual {
        // TODO allow sender to withdraw their payments from investments (as a beneficiary)
    }
}
