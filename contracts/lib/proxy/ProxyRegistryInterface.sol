pragma solidity 0.8.3;

import "./OwnableDelegateProxy.sol";

interface ProxyRegistryInterface {
    function delegateProxyImplementation() external returns (address);

    function proxies(address owner) external returns (OwnableDelegateProxy);
}
