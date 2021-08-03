//SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721("FlairTest", "FTS") {
    function mintExact(address to, uint256 tokenId) public returns (bool) {
        _mint(to, tokenId);
        return true;
    }
}
