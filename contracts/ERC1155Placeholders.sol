//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ERC1155Placeholders is Context, ERC1155 {
    using Counters for Counters.Counter;

    string public constant name = "Flair Placeholders";

    string public constant version = "0.1";

    /* Base URI for each token */
    string public baseURI;

    /* IPFS Hash by token ID */
    mapping(uint256 => string) public hashById;

    /* Token ID by IPFS Hash */
    mapping(string => uint256) public idByHash;

    /* Tokens Incremental ID */
    Counters.Counter private _idTracker;

    constructor(string memory _baseURI) ERC1155("") {
        baseURI = _baseURI;
    }

    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(baseURI, hashById[tokenId]));
    }

    function mint(
        address to,
        string calldata hash,
        uint256 amount,
        bytes memory data
    ) public virtual {
        /* CHECKS */
        require(idByHash[hash] == 0, "ERC1155/ALREADY_MINTED");

        /* EFFECTS */
        _idTracker.increment();
        uint256 newTokenId = _idTracker.current();

        hashById[newTokenId] = hash;
        idByHash[hash] = newTokenId;

        /* INTERACTIONS */
        _mint(to, newTokenId, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(
        address to,
        string[] memory ipfsHashes,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual {
        uint256[] memory ids = new uint256[](ipfsHashes.length);

        for (uint256 i = 0; i < ipfsHashes.length; i++) {
            /* CHECKS */
            require(idByHash[ipfsHashes[i]] == 0, "ERC1155/ALREADY_MINTED");

            /* EFFECTS */
            _idTracker.increment();
            uint256 newTokenId = _idTracker.current();

            hashById[newTokenId] = ipfsHashes[i];
            idByHash[ipfsHashes[i]] = newTokenId;

            ids[i] = newTokenId;
        }

        /* INTERACTIONS */
        _mintBatch(to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
