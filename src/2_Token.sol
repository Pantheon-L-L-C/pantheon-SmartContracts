pragma solidity ^0.8.4;

// SPDX-License-Identifier: MIT

import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "./2_Main.sol";

// temporary solution, not done yet

interface getBalance2 {
    function balance(address user) external view returns(uint256);
    function planarBal(address user) external view returns(uint);
    function GenBalPerAddy(address addy, uint gen) external view returns(uint);
    function yieldAmount(uint gen) external view returns(uint);
    function genTrack(uint gen) external view returns(uint);
}

contract YieldToken2 is Ownable, ERC20 {
    
    address pantheon;
    getBalance2 central;
    Main2 central2;
    uint256 initialDrop = 10 ether;

    mapping(address => uint256) yield;
    mapping(address => uint256) lastUpdate;

    event Rewarded(address user, uint rewards);

    constructor(address main) ERC20("Pantheon", "PNTH") {
        pantheon = main;
        central = getBalance2(main);
        central2 = Main2(main);
    }

    function updateOnMint(address receiver, uint256 amount, uint generation) external {
        require(msg.sender == pantheon);
        uint time = block.timestamp;
        uint last = lastUpdate[receiver];
        if (last > 0) { // homie has NFTs before
            uint pBal = central.planarBal(receiver);
            uint timeDiff = ((time - last) / 86400);
            uint256 newYield = timeDiff * calculateYield(receiver); //+ (pBal * planarRate)); // add gen 2 rate later
            yield[receiver] += newYield + (initialDrop * amount);
            lastUpdate[receiver] = time;
        } else { // firstMINT
            yield[receiver] += (initialDrop * amount);
            lastUpdate[receiver] = time;
        }   
    }

    function calculateYield(address receiver) internal view returns(uint) {
        uint total;
        for (uint i = 1; i <= central2.availableGens(); i++) {
            total += central.GenBalPerAddy(receiver, i) * central.genTrack(i).yield; // fix
        }
        return total;
    }

    function updateReward(address _from, address _to) external {
        require(msg.sender == pantheon);
        uint256 time = block.timestamp;
        uint256 lastFrom = lastUpdate[_from];
        uint lastTo = lastUpdate[_to];
        if (lastFrom > 0) {
            uint pBalFrom = central.planarBal(_from);
            uint timeDiff = ((time - lastFrom) / 86400);
            uint256 newYield = timeDiff * calculateYield(_from);// (pBalFrom * planarRate)); // add gen 2 rate later
            yield[_from] += newYield;
            lastUpdate[_from] = time;
        }
        if (_to != address(0)) { // no transferring to 0 address
            if (lastTo > 0) {
            uint pBalTo = central.planarBal(_to);
            uint timeDiff = ((time - lastTo) / 86400);
            uint newYield = timeDiff * calculateYield(_to); //+ (pBalTo * planarRate));
            yield[_to] += newYield;
            lastUpdate[_to] = time;
        } else {
            lastUpdate[_to] = time;
        }
        }
    }

    function updateRewardOnBurn(address user) external {
        require(msg.sender == pantheon);
        uint time = block.timestamp;
        uint last = lastUpdate[user];
        uint pBal = central.planarBal(user);
        uint timeDiff = (time - last) / 86400;
        uint newYield = timeDiff * calculateYield(user); //+ (pBal * planarRate));
        yield[user] += newYield + 100 ether; // burn rate based on GEN in main contract
        lastUpdate[user] = time;
    }

    function getClaimable(address user) external view returns(uint) {
        require(msg.sender == pantheon);
        uint rewards = yield[user];
        uint time = block.timestamp;
        uint timeDiff = time - lastUpdate[user];
        uint notUpdated = timeDiff * calculateYield(user);// + central.planarBal(user) * planarRate);
        return rewards + notUpdated;
    }

    function getReward(address user) external { // updateReward should be called right before this
        require(msg.sender == pantheon);
        uint rewards = yield[user];
        if (rewards > 0) {
            yield[user] = 0;
            _mint(user, rewards);
            emit Rewarded(user, rewards);
        }
    }

    function burn(address account, uint amount) external { // no need to override right now since no gen2 yet
        require(msg.sender == pantheon);
        _burn(account, amount);
    }

    // straight burn a gen 1 for 100-200 PANTHEON TOKENS
}