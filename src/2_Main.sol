pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "../lib/openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./2_Token.sol";

// temporary solution, not done yet, core funcs removed for readability.

contract Main2 is ERC721Enumerable, Ownable {
    
    using Strings for uint256;
    //uint reservedRemaining = 300;
    uint nextGenStart;
    uint public availableGens;
    uint startTime;
    uint currentMint = 0;
    uint firstPhase = 400000000000000000 wei; // 0.4 ETH
    uint secondPhase = 200000000000000000 wei; // 0.2 ETH
    uint generalPhase = 125000000000000000 wei; // 0.125 ETH
    uint councilWLValue = 100000000000000000 wei; // 0.1 ETH
    uint generalWLValue = 125000000000000000 wei; // 0.125 ETH
    address public treasury;
    YieldToken2 yield; 
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
    mapping(uint => GenTracker) public genTrack;
    mapping(uint => bool) isAvailableGen;
    mapping(address => mapping(uint => uint))GenBalPerAddy;
    mapping(uint => uint) yieldAmount;

    event StatusChanged(Status changeTo);
    event Minted(address addy, uint tokenID);

    struct GenTracker {
        uint maxSupply;
        uint currentID;
        uint reservedRemaining;
        bool burnEnabled;
        uint burnExchange;
        uint yield;
        uint price;
    }

    constructor(bytes32 _merkleRoot, bytes32 _sponsorMerkleRoot, address _treasury, address _planar) ERC721("Pantheon", "PNTH") {
        merkleRoot = _merkleRoot;
        sponsorMerkleRoot = _sponsorMerkleRoot;
        treasury = _treasury;
        planar = IERC1155(_planar);
    }

    function increaseAvailability(uint _maxSupply, uint _yield) external onlyOwner {
        availableGens++;
        isAvailableGen[availableGens] = true;
        genTrack[availableGens].currentID = nextGenStart;
        genTrack[availableGens].maxSupply = _maxSupply;
        nextGenStart + _maxSupply;
        yieldAmount[availableGens] = _yield;
    }

    function getGenX(uint _amount, uint _generation) external payable {
        require(isAvailableGen[_generation], "NOT AVAILABLE");
        require(msg.value == genTrack[_generation].price, "WRONG PRICE");
        if (genTrack[_generation].burn == true) {
            uint whichgen = genTrack[_generation].burnExchange;
            // burn sequence for that token ID
        }
        mintHero(_amount, _generation);
    }
    
    function setBaseURI(string memory bURI) external onlyOwner {
        baseURI = bURI;
    }


    function setTokenAddresses(address yieldaddy) external onlyOwner {
        yield = YieldToken2(yieldaddy);
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
        //reservedRemaining -= amount;
        mintHero(amount, 1);

    }

    function getCouncilWaitlistNFT(uint amount /** , bytes32[] calldata proof */) external payable {
        require(status == Status.CouncilWL, "Council Waitlist Not Active");
        require(msg.value == councilWLValue * amount, "Must send 0.1 ETH per");
        // bytes32 leaf = keccak256(abi.encodePacked(msg.sender, uint(0))); // address then amount
        // require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Credentials");
        require(balance[msg.sender] + amount <= 2, "Over Max Waitlist Allocation");
        mintHero(amount, 1);
    }

    function getGeneralWaitlistNFT(uint amount /** , bytes32[] calldata proof */) external payable {
        require(status == Status.GeneralWL, "General Waitlist Not Active");
        require(msg.value == generalWLValue * amount, "Must send 0.125 ETH per");
        // bytes32 leaf = keccak256(abi.encodePacked(msg.sender, uint(1)));
        // require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Credentials");
        require(balance[msg.sender] + amount <= 2, "Over Max Waitlist Allocation");
        mintHero(amount, 1);
    }

    function getPublicNFT(uint amount) external payable { // hard coded here, sep func for genX so price can be an attribute
        require(status == Status.PublicMint);
        require(amount <= 20);
        if (block.timestamp < startTime + 4 hours) {
            require(msg.value == firstPhase * amount, "Must send 0.4 ETH per");
            mintHero(amount, 1);
        } else if (block.timestamp < startTime + 8 hours) {
            require(msg.value == secondPhase * amount, "Must send 0.2 ETH per");
            mintHero(amount, 1);
        } else {
            require(msg.value == generalPhase * amount, "Must send 0.125 ETH per");
            mintHero(amount, 1);
        }
    }

    function mintHero(uint amount, uint generation) internal {
        require(genTrack[generation].currentID + amount <= genTrack[generation].maxSupply, "Exceeds Max Supply"); // + reservedRemaining, <= bc u have to mint the current mint
        yield.updateOnMint(msg.sender, amount, generation);
        balance[msg.sender] += amount;
        for (uint i = 0; i < amount; i++) {
            _safeMint(msg.sender, currentMint);
            emit Minted(msg.sender, currentMint);
            currentMint++;
        }
    }

    function getGenTwo(uint amount) external {
        require(balance[msg.sender] > 0, "Must have at least one Gen 1 NFT");
        yield.burn(msg.sender, (100 ether * amount));
        gen2Bal[msg.sender] += amount; // not using gen2Bal as a check so no reentrancy
    }

    function burnGen1(uint ID) external {
        require(msg.sender == ownerOf(ID), "Not owner of ID");
        _burn(ID);
        yield.updateRewardOnBurn(msg.sender);
        balance[msg.sender]--;        
    }

    // can have like an if statement for burn and a sep attribute
    // for which burn
    // things get clunky
}