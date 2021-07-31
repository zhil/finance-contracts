//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.7.5;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

import "./lib/proxy/AuthenticatedProxy.sol";
import "./lib/ERC1271.sol";

contract Offers is
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    EIP712Upgradeable
{
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    struct Offer {
        /* Address to receive the released investment funds. */
        address beneficiary;
        /* Offer funding options:
            upfrontPayment: Amount (percentage) to be released right after funding by investor.

            cliffPeriod: Cliff duration (in seconds) to not release any payment to offer maker.
            cliffPayment: Amount to release (in wei) to offer maker right after cliff period is finished.

            vestingBancorSupply: Bancor-formula supply variable when calculating how much to release as vesting.
            vestingBancorReserveBalance: Bancor-formula reserve-balance variable ^
            vestingBancorReserveRatio: Bancor-formula reserve-ratio variable ^

            priceBancorSupply: Bancor-formula supply variable when calculating price for each funding.
            priceBancorReserveBalance: Bancor-formula reserve-balance variable when calculating price for each funding.
            priceBancorReserveRatio: Bancor-formula reserve-ratio variable when calculating price for each funding.
        */
        uint256[9] fundingOptions;
        /* Offer registry address. */
        address registry;
        /* Offer maker address. */
        address maker;
        /* Offer static target. */
        address staticTarget;
        /* Offer static selector. */
        bytes4 staticSelector;
        /* Offer static extradata. */
        bytes staticExtradata;
        /* Offer maximum fill factor. */
        uint maximumFill;
        /* Offer listing timestamp. */
        uint listingTime;
        /* Offer expiration timestamp - 0 for no expiry. */
        uint expirationTime;
        /* Offer salt to prevent duplicate hashes. */
        uint salt;
    }

    /* A call, convenience struct. */
    struct Call {
        /* Target */
        address target;
        /* How to call */
        AuthenticatedProxy.HowToCall howToCall;
        /* Calldata */
        bytes data;
    }

    /* Trusted proxy registry contracts. */
    mapping(address => bool) public registries;

    /* Offer fill status, by maker address then by hash. */
    mapping(address => mapping(bytes32 => uint)) public fills;

    /* Offers verified by on-chain approval.
       Alternative to ECDSA signatures so that smart contracts can place offers directly.
       By maker address, then by hash. */
    mapping(address => mapping(bytes32 => bool)) public approved;

    /* Events */

    event OfferApproved     (bytes32 indexed hash, address registry, address indexed maker, address staticTarget, bytes4 staticSelector, bytes staticExtradata, uint maximumFill, uint listingTime, uint expirationTime, uint salt);
    event OfferFillChanged  (bytes32 indexed hash, address indexed maker, uint newFill);
    event OfferFunded       (bytes32 hash, address indexed maker, address indexed operator, uint newFill);

    /* Functions */

    function initialize() public initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(GOVERNOR_ROLE, _msgSender());

        __EIP712_init("FlairFunding", "0.1");
    }

    function _hashOffer(Offer memory offer)
        internal
        pure
        returns (bytes32 hash)
    {
        /* Per EIP 712. */
        return keccak256(abi.encode(
            OFFER_TYPEHASH,
            offer.beneficiary,
            offer.fundingOptions,
            offer.registry,
            offer.maker,
            offer.staticTarget,
            offer.staticSelector,
            keccak256(offer.staticExtradata),
            offer.maximumFill,
            offer.listingTime,
            offer.expirationTime,
            offer.salt
        ));
    }

    function _hashToSign(bytes32 offerHash)
        internal
        view
        returns (bytes32 hash)
    {
        /* Calculate the string a user must sign. */
        return keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            offerHash
        ));
    }

    function _exists(address what)
        internal
        view
        returns (bool)
    {
        uint size;
        assembly {
            size := extcodesize(what)
        }
        return size > 0;
    }

    function _validateOfferParameters(Offer memory offer, bytes32 hash)
        internal
        view
        returns (bool)
    {
        /* Offer must be listed and not be expired. */
        if (offer.listingTime > block.timestamp || (offer.expirationTime != 0 && offer.expirationTime <= block.timestamp)) {
            return false;
        }

        /* Offer must not have already been completely filled. */
        if (fills[offer.maker][hash] >= offer.maximumFill) {
            return false;
        }

        /* Offer static target must exist. */
        if (!_exists(offer.staticTarget)) {
            return false;
        }

        return true;
    }

    function _validateOfferAuthorization(bytes32 hash, address maker, bytes memory signature)
        internal
        view
        returns (bool)
    {
        /* Memoized authentication. If offer has already been partially filled, offer must be authenticated. */
        if (fills[maker][hash] > 0) {
            return true;
        }

        /* Offer authentication. Offer must be either: */

        /* (a): previously approved */
        if (approved[maker][hash]) {
            return true;
        }

        /* Calculate hash which must be signed. */
        bytes32 calculatedHashToSign = _hashToSign(hash);

        /* Determine whether signer is a contract or account. */
        bool isContract = _exists(maker);

        /* (b): Contract-only authentication: EIP/ERC 1271. */
        if (isContract) {
            if (ERC1271(maker).isValidSignature(abi.encodePacked(calculatedHashToSign), signature) == EIP_1271_MAGICVALUE) {
                return true;
            }
            return false;
        }

        /* (c): Account-only authentication: ECDSA-signed by maker. */
        (uint8 v, bytes32 r, bytes32 s) = abi.decode(signature, (uint8, bytes32, bytes32));

        if (ecrecover(calculatedHashToSign, v, r, s) == maker) {
            return true;
        }

        return false;
    }

    function _encodeStaticCall(Offer memory offer, Call memory call, address operator, uint value, uint fill)
        internal
        pure
        returns (bytes memory)
    {
        /* This array wrapping is necessary to preserve static call target function stack space. */
        address[7] memory addresses = [offer.beneficiary, offer.registry, offer.maker, call.target, matcher];
        uint[6] memory uints = [value, offer.maximumFill, offer.listingTime, offer.expirationTime, fill];

        return abi.encodeWithSelector(offer.staticSelector, offer.staticExtradata, addresses, call.howToCall, uints, call.data);
    }

    function _executeStaticCall(Offer memory offer, Call memory call, address matcher, uint value, uint fill)
        internal
        view
        returns (uint)
    {
        return staticCallUint(offer.staticTarget, _encodeStaticCall(offer, call, matcher, value, fill));
    }

    function _executeCall(ProxyRegistryInterface registry, address maker, Call memory call)
        internal
        returns (bool)
    {
        /* Assert valid registry. */
        require(registries[address(registry)]);

        /* Assert target _exists. */
        require(_exists(call.target), "Call target does not exist");

        /* Retrieve delegate proxy contract. */
        OwnableDelegateProxy delegateProxy = registry.proxies(maker);

        /* Assert existence. */
        require(delegateProxy != OwnableDelegateProxy(0), "Delegate proxy does not exist for maker");

        /* Assert implementation. */
        require(delegateProxy.implementation() == registry.delegateProxyImplementation(), "Incorrect delegate proxy implementation for maker");

        /* Typecast. */
        AuthenticatedProxy proxy = AuthenticatedProxy(address(delegateProxy));

        /* Execute offer. */
        return proxy.proxy(call.target, call.howToCall, call.data);
    }

    function _approveOfferHash(bytes32 hash)
        internal
    {
        /* CHECKS */

        /* Assert offer has not already been approved. */
        require(!approved[msg.sender][hash], "OFFERS/ALREADY_APPROVED");

        /* EFFECTS */

        /* Mark offer as approved. */
        approved[msg.sender][hash] = true;
    }

    function _approveOffer(Offer memory offer)
        internal
    {
        /* CHECKS */

        /* Assert sender is authorized to approve offer. */
        require(offer.maker == msg.sender, "OFFERS/DENIED");

        /* Calculate offer hash. */
        bytes32 hash = _hashOffer(offer);

        /* Approve offer hash. */
        _approveOfferHash(hash);

        /* Log approval event. */
        emit OfferApproved(hash, offer.registry, offer.maker, offer.staticTarget, offer.staticSelector, offer.staticExtradata, offer.maximumFill, offer.listingTime, offer.expirationTime, offer.salt);
    }

    function _setOfferFill(bytes32 hash, uint fill)
        internal
    {
        /* CHECKS */

        /* Assert fill is not already set. */
        require(fills[msg.sender][hash] != fill, "OFFERS/ALREADY_SET");

        /* EFFECTS */

        /* Mark offer as accordingly filled. */
        fills[msg.sender][hash] = fill;

        /* Log offer fill change event. */
        emit OfferFillChanged(hash, msg.sender, fill);
    }

    function _executeOffer(
        Offer offer,
        Call call,
        bytes signature
    )  internal nonReentrant returns (uint256, uint256) {
        /* CHECKS */

        /* Calculate offer hash. */
        bytes32 hash = _hashOffer(offer);

        /* Check offer validity. */
        require(_validateOfferParameters(offer, hash), "OFFERS/INVALID");

        /* Check offer authorization. */
        require(_validateOfferAuthorization(hash, offer.maker, signature), "OFFERS/UNAUTHORIZED");

        /* INTERACTIONS */

        /* Execute call, assert success. */
        require(_executeCall(ProxyRegistryInterface(offer.registry), offer.maker, call), "OFFERS/FAILED");

        /* Fetch previous offer fill. */
        uint previousFill = fills[offer.maker][hash];

        /* Execute offer static call, assert success, capture returned new fill. */
        uint newFill = _executeStaticCall(offer, call, msg.sender, msg.value, previousFill);

        /* EFFECTS */

        /* Update offer fill, if necessary. */
        if (newFill != previousFill) {
            fills[offer.maker][hash] = newFill;
        }

        /* LOGS */

        /* Log match event. */
        emit OfferFunded(hash, offer.maker, msg.sender, newFill);

        return (previousFill, newFill);
    }
}