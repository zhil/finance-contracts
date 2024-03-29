pragma solidity 0.8.3;

import "./OwnedUpgradabilityProxy.sol";

contract OwnableDelegateProxy is OwnedUpgradeabilityProxy {
    constructor(
        address owner,
        address initialImplementation,
        bytes memory data
    ) public {
        setUpgradeabilityOwner(owner);
        _upgradeTo(initialImplementation);
        (bool success, ) = initialImplementation.delegatecall(data);
        require(success, "OwnableDelegateProxy failed implementation");
    }
}
