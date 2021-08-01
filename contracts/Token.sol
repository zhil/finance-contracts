//SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

import "./lib/BancorFormula.sol";

contract Token is
    Initializable,
    ContextUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC20BurnableUpgradeable,
    ERC20PausableUpgradeable,
    ERC20SnapshotUpgradeable,
    ERC20PermitUpgradeable,
    BancorFormula
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint32 internal _rewardRatio;
    uint256 internal _totalContribution;
    uint256 internal _totalRewarded;

    function initialize(string memory name, string memory symbol, uint32 rewardRatio) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _msgSender());

        _rewardRatio = rewardRatio;
    }

    /* MODIFIERS */
    modifier isGovernor() {
        require(hasRole(GOVERNOR_ROLE, _msgSender()), "TOKEN/NOT_GOVERNOR");
        _;
    }

    /* ADMIN */
    function pause() public virtual isGovernor() {
        _pause();
    }

    function unpause() public virtual isGovernor() {
        _unpause();
    }

    function setRewardRatio(uint32 newRatio) public virtual isGovernor() {
        _rewardRatio = newRatio;
    }

    /* FUNCTIONS */
    function mint(address to, uint256 amount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "TOKEN/NOT_MINTER");
        _mint(to, amount);
    }

    function reward(address to, uint256 contributionAmount) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "TOKEN/NOT_MINTER");

        uint256 reward = purchaseTargetAmount(_totalRewarded, _totalContribution, _rewardRatio, contributionAmount);
        _totalRewarded += reward;
        _totalContribution += contributionAmount;

        _mint(to, reward);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20Upgradeable, ERC20PausableUpgradeable, ERC20SnapshotUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);
    }
}
