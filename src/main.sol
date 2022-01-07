pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./token.sol";
import "./gen2.sol";

contract Main is ERC721Enumerable, Ownable {
    
    using Strings for uint256;
    uint reservedRemaining = 300;
    uint startTime;
    uint currentMint = 0;
    uint firstPhase = 400000000000000000 wei; // 0.4 ETH
    uint secondPhase = 200000000000000000 wei; // 0.2 ETH
    uint generalPhase = 125000000000000000 wei; // 0.125 ETH
    uint councilWLValue = 100000000000000000 wei; // 0.1 ETH
    uint generalWLValue = 125000000000000000 wei; // 0.125 ETH
    uint[] planarIds;
    address public treasury;
    YieldToken yield; 
    Gen2 generationTwo;
    bytes32 public merkleRoot;
    bytes32 public sponsorMerkleRoot;
    Status public status;
    IERC1155 planar;
    string public baseURI;

    enum Status {PreLaunch, CouncilWL, GeneralWL, PublicMint, Paused } // 0, 1, 2, 3, 4 // 0 -> Council WL, 1 -> GeneralWL

    mapping(address => uint) public balance;
    mapping(address => uint) public planarBal;
    mapping(address => uint) public gen2Bal;
    mapping(address => bool) sponsorClaimed;

    event StatusChanged(Status changeTo);
    event Minted(address addy, uint tokenID);

    constructor(bytes32 _merkleRoot, bytes32 _sponsorMerkleRoot, address _treasury, address _planar) ERC721("Pantheon", "PNTH") {
        merkleRoot = _merkleRoot;
        sponsorMerkleRoot = _sponsorMerkleRoot;
        treasury = _treasury;
        planar = IERC1155(_planar);
    }

    function setBaseURI(string memory bURI) external onlyOwner {
        baseURI = bURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString())) : "";
        // add a base extension somewhere indicating .json
    }

    function setTokenAddresses(address yieldaddy, address gen2addy) external onlyOwner {
        yield = YieldToken(yieldaddy);
        generationTwo = Gen2(gen2addy);
    }

    function changeStatus(uint changeTo) external onlyOwner {
        if (changeTo == 1) {
            status = Status.CouncilWL;
            emit StatusChanged(Status.CouncilWL);
        }
        if (changeTo == 2) {
            status = Status.GeneralWL;
            emit StatusChanged(Status.GeneralWL);
        }
        if (changeTo == 3) {
            status = Status.PublicMint;
            startTime = block.timestamp;
            emit StatusChanged(Status.PublicMint);
        }
        if (changeTo == 4) {
            status = Status.Paused;
            emit StatusChanged(Status.Paused);
        }
    }

    function getSponsorshipNFT(uint amount /** , bytes32[] calldata proof */) external payable {
        require(sponsorClaimed[msg.sender] == false, "Already Claimed");
        //bytes32 leaf = keccak256(abi.encodePacked(msg.sender, amount));
        //require(MerkleProof.verify(proof, sponsorMerkleRoot, leaf), "Invalid Credentials");
        sponsorClaimed[msg.sender] = true;
        reservedRemaining -= amount;
        mintHero(amount);

    }

    function getCouncilWaitlistNFT(uint amount /** , bytes32[] calldata proof */) external payable {
        require(status == Status.CouncilWL, "Council Waitlist Not Active");
        require(msg.value == councilWLValue * amount, "Must send 0.1 ETH per");
        // bytes32 leaf = keccak256(abi.encodePacked(msg.sender, uint(0))); // address then amount
        // require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Credentials");
        require(balance[msg.sender] + amount <= 2, "Over Max Waitlist Allocation");
        mintHero(amount);
    }

    function getGeneralWaitlistNFT(uint amount /** , bytes32[] calldata proof */) external payable {
        require(status == Status.GeneralWL, "General Waitlist Not Active");
        require(msg.value == generalWLValue * amount, "Must send 0.125 ETH per");
        // bytes32 leaf = keccak256(abi.encodePacked(msg.sender, uint(1)));
        // require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Credentials");
        require(balance[msg.sender] + amount <= 2, "Over Max Waitlist Allocation");
        mintHero(amount);
    }

    function getPublicNFT(uint amount) external payable {
        require(status == Status.PublicMint);
        require(amount <= 20);
        if (block.timestamp < startTime + 4 hours) {
            require(msg.value == firstPhase * amount, "Must send 0.4 ETH per");
            mintHero(amount);
        } else if (block.timestamp < startTime + 8 hours) {
            require(msg.value == secondPhase * amount, "Must send 0.2 ETH per");
            mintHero(amount);
        } else {
            require(msg.value == generalPhase * amount, "Must send 0.125 ETH per");
            mintHero(amount);
        }
    }

    function mintHero(uint amount) internal {
        require(currentMint + amount + reservedRemaining < 11111, "Exceeds Max Supply");
        yield.updateOnMint(msg.sender, amount);
        balance[msg.sender] += amount;
        for (uint i = 0; i < amount; i++) {
            _safeMint(msg.sender, currentMint);
            emit Minted(msg.sender, currentMint);
            currentMint++;
        }
    }

    function transferFrom(address from, address to, uint tokenId) public override {
        yield.updateReward(from, to);
        balance[from]--;
        balance[to]++;
        ERC721.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint tokenId) public override {
        yield.updateReward(from, to);
        balance[from]--;
        balance[to]++;
        ERC721.safeTransferFrom(from, to, tokenId);
    }

    function setPlanarIds(uint[6] memory ids) external onlyOwner {
        planarIds = ids;
    }

    function claimPlanarBal(address[] memory sender) external {
        for (uint i = 0; i < sender.length; i++) {
            require(sender[i] == msg.sender, "NOT MSG.SENDER ADDRESS");
        }
        uint[] memory result = planar.balanceOfBatch(sender, planarIds); // uint[6]
        uint total;
        for (uint i = 0; i < result.length; i++) {
            total += result[i];
        }
        planarBal[msg.sender] = total;
    }

    function getGenTwo(uint amount) external {
        require(balance[msg.sender] > 0, "Must have at least one Gen 1 NFT");
        yield.burn(msg.sender, (100 ether * amount));
        generationTwo.mintNextGen(msg.sender, amount);
        gen2Bal[msg.sender] += amount; // not using gen2Bal as a check so no reentrancy
    }

    function burnGen1(uint ID) external {
        require(msg.sender == ownerOf(ID), "Not owner of ID");
        _burn(ID);
        yield.updateRewardOnBurn(msg.sender);
        balance[msg.sender]--;        
    }

    function redeemReward() external {
        yield.updateReward(msg.sender, address(0));
        yield.getReward(msg.sender);
    }

    function getClaimable() external view returns(uint) { // could have this just be via token.sol, removed require(pantheon) for now from that contract
        return yield.getClaimable(msg.sender);
    }

    function checkBalance() external view returns(uint) {
        return yield.balanceOf(msg.sender);
    }

    function withdraw() external payable onlyOwner {
        uint balanceWithdraw = address(this).balance;
        payable(msg.sender).transfer(balanceWithdraw);
    }
}