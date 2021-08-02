pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./lib/proxy/OwnableDelegateProxy.sol";
import "./lib/proxy/ProxyRegistryInterface.sol";
import "./lib/proxy/AuthenticatedProxy.sol";

/**
 * @title Registry
 * @author Wyvern Protocol Developers
 */
contract Registry is Ownable, ProxyRegistryInterface {
    string public constant name = "Flair Proxy Registry";

    /* Whether the initial auth address has been set. */
    bool public initialAddressSet = false;

    /* DelegateProxy implementation contract. Must be initialized. */
    address public override delegateProxyImplementation;

    /* Authenticated proxies by user. */
    mapping(address => OwnableDelegateProxy) public override proxies;

    /* Contracts pending access. */
    mapping(address => uint256) public pending;

    /* Contracts allowed to call those proxies. */
    mapping(address => bool) public contracts;

    /* Delay period for adding an authenticated contract.
       This mitigates a particular class of potential attack on the Wyvern DAO (which owns this registry) - if at any point the value of assets held by proxy contracts exceeded the value of half the WYV supply (votes in the DAO),
       a malicious but rational attacker could buy half the Wyvern and grant themselves access to all the proxy contracts. A delay period renders this attack nonthreatening - given two weeks, if that happened, users would have
       plenty of time to notice and transfer their assets.
    */
    uint256 public DELAY_PERIOD = 2 weeks;

    constructor() public {
        AuthenticatedProxy impl = new AuthenticatedProxy();
        impl.initialize(address(this), this);
        impl.setRevoke(true);
        delegateProxyImplementation = address(impl);
    }

    /**
     * Grant authentication to the initial Flair contract
     *
     * @dev No delay, can only be called once - after that the standard registry process with a delay must be used
     * @param authAddress Address of the contract to grant authentication
     */
    function grantInitialAuthentication(address authAddress) public onlyOwner {
        require(!initialAddressSet, "Flair Proxy Registry initial address already set");
        initialAddressSet = true;
        contracts[authAddress] = true;
    }

    /**
     * Start the process to enable access for specified contract. Subject to delay period.
     *
     * @dev Registry owner only
     * @param addr Address to which to grant permissions
     */
    function startGrantAuthentication(address addr) public onlyOwner {
        require(!contracts[addr] && pending[addr] == 0, "Contract is already allowed in registry, or pending");
        pending[addr] = block.timestamp;
    }

    /**
     * End the process to enable access for specified contract after delay period has passed.
     *
     * @dev Registry owner only
     * @param addr Address to which to grant permissions
     */
    function endGrantAuthentication(address addr) public onlyOwner {
        require(
            !contracts[addr] && pending[addr] != 0 && ((pending[addr] + DELAY_PERIOD) < block.timestamp),
            "Contract is no longer pending or has already been approved by registry"
        );
        pending[addr] = 0;
        contracts[addr] = true;
    }

    /**
     * Revoke access for specified contract. Can be done instantly.
     *
     * @dev Registry owner only
     * @param addr Address of which to revoke permissions
     */
    function revokeAuthentication(address addr) public onlyOwner {
        contracts[addr] = false;
    }

    /**
     * Register a proxy contract with this registry
     *
     * @dev Must be called by the user which the proxy is for, creates a new AuthenticatedProxy
     * @return proxy New AuthenticatedProxy contract
     */
    function registerProxy() public returns (OwnableDelegateProxy proxy) {
        return registerProxyFor(msg.sender);
    }

    /**
     * Register a proxy contract with this registry, overriding any existing proxy
     *
     * @dev Must be called by the user which the proxy is for, creates a new AuthenticatedProxy
     * @return proxy New AuthenticatedProxy contract
     */
    function registerProxyOverride() public returns (OwnableDelegateProxy proxy) {
        proxy = new OwnableDelegateProxy(
            msg.sender,
            delegateProxyImplementation,
            abi.encodeWithSignature("initialize(address,address)", msg.sender, address(this))
        );
        proxies[msg.sender] = proxy;
        return proxy;
    }

    /**
     * Register a proxy contract with this registry
     *
     * @dev Can be called by any user
     * @return proxy New AuthenticatedProxy contract
     */
    function registerProxyFor(address user) public returns (OwnableDelegateProxy proxy) {
        require(address(proxies[user]) == address(0), "User already has a proxy");
        proxy = new OwnableDelegateProxy(
            user,
            delegateProxyImplementation,
            abi.encodeWithSignature("initialize(address,address)", user, address(this))
        );
        proxies[user] = proxy;
        return proxy;
    }

    /**
     * Transfer access
     */
    function transferAccessTo(address from, address to) public {
        OwnableDelegateProxy proxy = proxies[from];

        /* CHECKS */
        require(OwnableDelegateProxy(payable(msg.sender)) == proxy, "Proxy transfer can only be called by the proxy");
        require(address(proxies[to]) == address(0), "Proxy transfer has existing proxy as destination");

        /* EFFECTS */
        delete proxies[from];
        proxies[to] = proxy;
    }
}
