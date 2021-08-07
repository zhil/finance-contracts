//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";

import "./lib/proxy/AuthenticatedProxy.sol";
import "./lib/StaticCaller.sol";
import "./lib/ERC1271.sol";

import "hardhat/console.sol";

contract Campaigns is ContextUpgradeable, ReentrancyGuardUpgradeable, StaticCaller, EIP712Upgradeable {
    bytes4 internal constant ERC1271_MAGICVALUE = 0x20c13b0b; // bytes4(keccak256("isValidSignature(bytes,bytes)")

    struct Campaign {
        /* Address to receive the released investment funds. */
        address beneficiary;
        /*
         * Campaign funding options:
         * - upfrontPayment: Amount (percentage) to be released right after funding by investor.
         *
         * - cliffPeriod: Cliff duration (in seconds) to not release any payment to campaign creator.
         * - cliffPayment: Amount to release (in wei) to campaign creator right after cliff period is finished.
         *
         * - vestingPeriod: How long to stretch the vesting.
         * - vestingRatio: Bancor-formula reserve-ratio variable when calculating released amount.
         *
         * - priceBancorSupply: Bancor-formula supply variable when calculating price for each funding.
         * - priceBancorReserveBalance: Bancor-formula reserve-balance variable ^.
         * - priceBancorReserveRatio: Bancor-formula reserve-ratio variable ^.
         */
        uint256[8] fundingOptions;
        /* Campaign registry address. */
        address registry;
        /* Campaign creator address. */
        address creator;
        /* Campaign funding static target for validating if user-defined call is acceptable upon investment. */
        address contributionValidatorTarget;
        /* Campaign funding static selector. */
        bytes4 contributionValidatorSelector;
        /* Campaign funding static extradata. */
        bytes contributionValidatorExtradata;
        /* Campaign cancellation static target for validating if user-defined call is acceptable upon requesting a refund. */
        address cancellationValidatorTarget;
        /* Campaign cancellation static selector. */
        bytes4 cancellationValidatorSelector;
        /* Campaign cancellation static extradata. */
        bytes cancellationValidatorExtradata;
        /* Campaign maximum fill factor. */
        uint256 maximumFill;
        /* Campaign listing timestamp. */
        uint256 listingTime;
        /* Campaign expiration timestamp - 0 for no expiry. */
        uint256 expirationTime;
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

    /* CONSTANTS */

    /* Order typehash for EIP 712 compatibility. */
    bytes32 constant CAMPAIGN_TYPEHASH =
        keccak256(
            "Campaign(address beneficiary,uint256[8] fundingOptions,address registry,address creator,address contributionValidatorTarget,bytes4 contributionValidatorSelector,bytes contributionValidatorExtradata,address cancellationValidatorTarget,bytes4 cancellationValidatorSelector,bytes cancellationValidatorExtradata,uint256 maximumFill,uint256 listingTime,uint256 expirationTime)"
        );

    /* VARIABLES */

    /* Trusted proxy registry contracts. */
    mapping(address => bool) public registries;

    /* Campaign fill amounts, by creator address then by hash. */
    mapping(address => mapping(bytes32 => uint256)) public fills;

    /* Campaigns verified by on-chain approval.
       Alternative to ECDSA signatures so that smart contracts can place campaigns directly.
       By creator address, then by hash. */
    mapping(address => mapping(bytes32 => bool)) public approved;

    /* EVENTS */

    event CampaignApproved(
        bytes32 indexed hash,
        address registry,
        address indexed creator,
        address contributionValidatorTarget,
        bytes4 contributionValidatorSelector,
        bytes contributionValidatorExtradata,
        address cancellationValidatorTarget,
        bytes4 cancellationValidatorSelector,
        bytes cancellationValidatorExtradata,
        uint256 maximumFill,
        uint256 listingTime,
        uint256 expirationTime
    );
    event CampaignFillChanged(bytes32 indexed hash, address indexed creator, uint256 newFill);

    /* FUNCTIONS */

    function __Campaign_init(string memory name, string memory version) internal initializer {
        __EIP712_init_unchained(name, version);
        __ReentrancyGuard_init_unchained();
        __Campaign_init_unchained();
    }

    function __Campaign_init_unchained() internal initializer {}

    function _hashCampaign(Campaign memory campaign) internal pure returns (bytes32 hash) {
        /* Per EIP 712. */
        return
            keccak256(
                abi.encode(
                    CAMPAIGN_TYPEHASH,
                    campaign.beneficiary,
                    keccak256(abi.encode(campaign.fundingOptions)),
                    campaign.registry,
                    campaign.creator,
                    campaign.contributionValidatorTarget,
                    campaign.contributionValidatorSelector,
                    keccak256(campaign.contributionValidatorExtradata),
                    campaign.cancellationValidatorTarget,
                    campaign.cancellationValidatorSelector,
                    keccak256(campaign.cancellationValidatorExtradata),
                    campaign.maximumFill,
                    campaign.listingTime,
                    campaign.expirationTime
                )
            );
    }

    function _hashToSign(bytes32 campaignHash) internal view returns (bytes32 hash) {
        /* Calculate the string a user must sign. */
        return _hashTypedDataV4(campaignHash);
    }

    function _exists(address what) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(what)
        }
        return size > 0;
    }

    function _validateCampaignFundingParameters(Campaign memory campaign, bytes32 hash) internal view returns (bool) {
        /* Campaign must be listed and not be expired. */
        if (
            campaign.listingTime > block.timestamp ||
            (campaign.expirationTime != 0 && campaign.expirationTime <= block.timestamp)
        ) {
            return false;
        }

        /* Campaign must not have already been completely filled. */
        if (fills[campaign.creator][hash] >= campaign.maximumFill) {
            return false;
        }

        /* Campaign static target must exist. */
        if (!_exists(campaign.contributionValidatorTarget)) {
            return false;
        }

        return true;
    }

    function _validateCampaignCancellationParameters(Campaign memory campaign, bytes32 hash) internal view returns (bool) {
        /* Campaign must be listed and not be expired. */
        if (
            campaign.listingTime > block.timestamp
        ) {
            return false;
        }

        /* Campaign must have already been filled. */
        if (fills[campaign.creator][hash] < 1) {
            return false;
        }

        /* Campaign cancellation validator static target must exist. */
        if (!_exists(campaign.cancellationValidatorTarget)) {
            return false;
        }

        return true;
    }

    function _validateCampaignAuthorization(
        bytes32 hash,
        address creator,
        bytes memory signature
    ) internal view returns (bool) {
        /* Memoized authentication. If campaign has already been partially filled, campaign must be authenticated. */
        if (fills[creator][hash] > 0) {
            return true;
        }

        /* Campaign authentication. Campaign must be either: */

        /* (a): previously approved */
        if (approved[creator][hash]) {
            return true;
        }

        /* Calculate hash which must be signed. */
        bytes32 calculatedHashToSign = _hashToSign(hash);

        /* Determine whether signer is a contract or account. */
        bool isContract = _exists(creator);

        /* (b): Contract-only authentication: EIP/ERC 1271. */
        if (isContract) {
            if (
                ERC1271(creator).isValidSignature(abi.encodePacked(calculatedHashToSign), signature) == ERC1271_MAGICVALUE
            ) {
                return true;
            }
            return false;
        }

        /* (c): Account-only authentication: ECDSA-signed by creator. */
        (uint8 v, bytes32 r, bytes32 s) = abi.decode(signature, (uint8, bytes32, bytes32));

        address recoveredAddr = ecrecover(calculatedHashToSign, v, r, s);

        if (recoveredAddr == creator) {
            return true;
        }

        return false;
    }

    function _encodeFundingStaticValidator(
        Campaign memory campaign,
        Call memory call,
        address taker,
        uint256 value,
        uint256 fill
    ) internal pure returns (bytes memory) {
        /* This array wrapping is necessary to preserve static call target function stack space. */
        address[5] memory addresses = [campaign.beneficiary, campaign.registry, campaign.creator, call.target, taker];
        uint256[5] memory uints = [value, campaign.maximumFill, campaign.listingTime, campaign.expirationTime, fill];

        return
            abi.encodeWithSelector(
                campaign.contributionValidatorSelector,
                campaign.contributionValidatorExtradata,
                addresses,
                call.howToCall,
                uints,
                call.data
            );
    }

    function _executeContributionStaticValidator(
        Campaign memory campaign,
        Call memory call,
        address taker,
        uint256 value,
        uint256 fill
    ) internal view returns (uint256) {
        return
            staticCallUint256(
                campaign.contributionValidatorTarget,
                _encodeFundingStaticValidator(campaign, call, taker, value, fill)
            );
    }

    function _encodeCancellationStaticValidator(
        Campaign memory campaign,
        Call memory call,
        address taker,
        uint256 value,
        uint256 fill
    ) internal pure returns (bytes memory) {
        /* This array wrapping is necessary to preserve static call target function stack space. */
        address[5] memory addresses = [campaign.beneficiary, campaign.registry, campaign.creator, call.target, taker];
        uint256[5] memory uints = [value, campaign.maximumFill, campaign.listingTime, campaign.expirationTime, fill];

        return
            abi.encodeWithSelector(
                campaign.cancellationValidatorSelector,
                campaign.cancellationValidatorExtradata,
                addresses,
                call.howToCall,
                uints,
                call.data
            );
    }

    function _executeCancellationStaticValidator(
        Campaign memory campaign,
        Call memory call,
        address taker,
        uint256 value,
        uint256 fill
    ) internal view returns (uint256) {
        return
            staticCallUint256(
                campaign.cancellationValidatorTarget,
                _encodeCancellationStaticValidator(campaign, call, taker, value, fill)
            );
    }

    function _executeCall(
        ProxyRegistryInterface registry,
        address creator,
        Call memory call
    ) internal returns (bool) {
        /* Assert valid registry. */
        require(registries[address(registry)]);

        /* Assert target _exists. */
        require(_exists(call.target), "Call target does not exist");

        /* Retrieve delegate proxy contract. */
        OwnableDelegateProxy delegateProxy = registry.proxies(creator);

        /* Assert existence. */
        require(delegateProxy != OwnableDelegateProxy(payable(0)), "Delegate proxy does not exist for creator");

        /* Assert implementation. */
        require(
            delegateProxy.implementation() == registry.delegateProxyImplementation(),
            "Incorrect delegate proxy implementation for creator"
        );

        /* Typecast. */
        AuthenticatedProxy proxy = AuthenticatedProxy(payable(delegateProxy));

        /* Execute campaign. */
        return proxy.proxy(call.target, call.howToCall, call.data);
    }

    function _approveCampaignHash(bytes32 hash) internal {
        /* CHECKS */

        /* Assert campaign has not already been approved. */
        require(!approved[msg.sender][hash], "CAMPAIGNS/ALREADY_APPROVED");

        /* EFFECTS */

        /* Mark campaign as approved. */
        approved[msg.sender][hash] = true;
    }

    function _approveCampaign(Campaign memory campaign) internal {
        /* CHECKS */

        /* Assert sender is authorized to approve campaign. */
        require(campaign.creator == msg.sender, "CAMPAIGNS/DENIED");

        /* Calculate campaign hash. */
        bytes32 hash = _hashCampaign(campaign);

        /* Approve campaign hash. */
        _approveCampaignHash(hash);

        /* Log approval event. */
        emit CampaignApproved(
            hash,
            campaign.registry,
            campaign.creator,
            campaign.contributionValidatorTarget,
            campaign.contributionValidatorSelector,
            campaign.contributionValidatorExtradata,
            campaign.cancellationValidatorTarget,
            campaign.cancellationValidatorSelector,
            campaign.cancellationValidatorExtradata,
            campaign.maximumFill,
            campaign.listingTime,
            campaign.expirationTime
        );
    }

    function _setCampaignFill(bytes32 hash, uint256 fill) internal {
        /* CHECKS */

        /* Assert fill is not already set. */
        require(fills[msg.sender][hash] != fill, "CAMPAIGNS/ALREADY_SET");

        /* EFFECTS */

        /* Mark campaign as accordingly filled. */
        fills[msg.sender][hash] = fill;

        /* Log campaign fill change event. */
        emit CampaignFillChanged(hash, msg.sender, fill);
    }

    function _executeCampaignContribution(
        Campaign memory campaign,
        Call memory call,
        bytes memory signature
    )
        internal
        nonReentrant
        returns (
            bytes32 hash,
            uint256 previousFill,
            uint256 newFill
        )
    {
        /* CHECKS */

        /* Calculate campaign hash. */
        hash = _hashCampaign(campaign);

        /* Check campaign validity. */
        require(_validateCampaignFundingParameters(campaign, hash), "CAMPAIGNS/FUNDING_INVALID");

        /* Check campaign authorization. */
        require(_validateCampaignAuthorization(hash, campaign.creator, signature), "CAMPAIGNS/FUNDING_UNAUTHORIZED");

        /* INTERACTIONS */

        /* Execute call, assert success. */
        require(_executeCall(ProxyRegistryInterface(campaign.registry), campaign.creator, call), "CAMPAIGNS/FUNDING_FAILED");

        /* Fetch previous campaign fill. */
        previousFill = fills[campaign.creator][hash];

        /* Execute campaign static call, assert success, capture returned new fill. */
        newFill = _executeContributionStaticValidator(campaign, call, msg.sender, msg.value, previousFill);

        /* EFFECTS */

        /* Update campaign fill. */
        require(newFill > previousFill, "CAMPAIGNS/FILL_UNCHANGED");
        fills[campaign.creator][hash] = newFill;

        return (hash, previousFill, newFill);
    }

    function _executeCampaignCancellation(
        Campaign memory campaign,
        Call memory call,
        bytes memory signature
    )
        internal
        nonReentrant
        returns (
            bytes32 hash,
            uint256 previousFill,
            uint256 newFill
        )
    {
        /* CHECKS */

        /* Calculate campaign hash. */
        hash = _hashCampaign(campaign);

        /* Check campaign validity. */
        require(_validateCampaignCancellationParameters(campaign, hash), "CAMPAIGNS/CANCELLATION_INVALID");

        /* Check campaign authorization. */
        require(_validateCampaignAuthorization(hash, campaign.creator, signature), "CAMPAIGNS/CANCELLATION_UNAUTHORIZED");

        /* INTERACTIONS */

        /* Execute call, assert success. */
        require(_executeCall(ProxyRegistryInterface(campaign.registry), campaign.creator, call), "CAMPAIGNS/CANCELLATION_FAILED");

        /* Fetch previous campaign fill. */
        previousFill = fills[campaign.creator][hash];

        /* Execute campaign static call, assert success, capture returned new fill. */
        newFill = _executeCancellationStaticValidator(campaign, call, msg.sender, msg.value, previousFill);

        /* EFFECTS */

        /* Update campaign fill. */
        require(newFill < previousFill, "CAMPAIGNS/FILL_UNCHANGED");
        fills[campaign.creator][hash] = newFill;

        return (hash, previousFill, newFill);
    }
}
