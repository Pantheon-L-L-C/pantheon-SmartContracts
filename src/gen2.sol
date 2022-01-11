pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Gen2 is ERC721Enumerable, Ownable {

    using Strings for uint256;

    uint currentMint = 11111;
    uint maxSupply = 122222;
    address pantheon;
    string public baseURI;

    event Minted(address minter, uint tokenID);

    constructor(address main) ERC721("Pantheon2", "PNTH") {
        pantheon = main;
    }

    function mintNextGen(address receiver, uint amount) external {
        require(msg.sender == pantheon);
        require(currentMint + amount <= maxSupply);
        for (uint i = 0; i < amount; i++) {
            _safeMint(receiver, currentMint);
            emit Minted(receiver, currentMint);
            currentMint++;
        }
    }

    function setBaseURI(string memory bURI) external onlyOwner {
        baseURI = bURI;
    }

    function getBaseURI() public view returns(string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
        // json
    }
}   
