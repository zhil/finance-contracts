import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract TestERC721 is ERC721("FlairTest", "FTS") {
    constructor () public {
        mintExact(msg.sender, 1);
        mintExact(msg.sender, 2);
        mintExact(msg.sender, 3);
    }

    function mintExact(address to, uint256 tokenId) public returns (bool) {
        _mint(to, tokenId);
        return true;
    }
}
