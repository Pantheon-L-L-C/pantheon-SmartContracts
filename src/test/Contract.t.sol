// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "../../lib/ds-test/src/test.sol";
import "../gen2.sol";
import "../main.sol";
import "../token.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

interface Vm {
    function warp(uint256 x) external;
    function expectRevert(bytes calldata) external;
}

contract ContractTest is DSTest, ERC721Holder {
    Main main;
    YieldToken yield;
    Gen2 gen2;
    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        bytes32 root = 0x4d32c58ef0a2d0cea440002d346d7d413c49f93ec252522642e1e4937e85089a;
        bytes32 sponsorRoot = 0x84493f27e0e7fd3d937542fd25dd93e8b5501b32f4a172a28e115d847b5f6e9e;
        address treasury = 0x6cB5FceFa0037c373aD1Ec7717874117D353bF49;
        address planar = 0x495f947276749Ce646f68AC8c248420045cb7b5e;
        main = new Main(root, sponsorRoot, treasury, planar);
        yield = new YieldToken(address(main));
        gen2 = new Gen2(address(main));
        main.setTokenAddresses(address(yield), address(gen2));
        uint[6] memory ids = [
            82476994283048407923634290126317238187642587124158938589168337524286338105358,
            82476994283048407923634290126317238187642587124158938589168337519888291594254,
            82476994283048407923634290126317238187642587124158938589168337522087314849806,
            82476994283048407923634290126317238187642587124158938589168337520987803222030,
            82476994283048407923634290126317238187642587124158938589168337523186826477582,
            82476994283048407923634290126317238187642587124158938589168337518788779966478];
        main.setPlanarIds(ids);
    }

    function testFail_AllMintsPreLaunch() public {
        main.getCouncilWaitlistNFT(2);
        main.getGeneralWaitlistNFT(2);
        main.getPublicNFT(10);
    }

    function test_CouncilWLMint() public {
        main.changeStatus(1);
        main.getCouncilWaitlistNFT{value: 0.2 ether}(2);
    }

    function testFail_AllMintsDuringCouncilWL() public {
        main.changeStatus(1);
        main.getGeneralWaitlistNFT{value: 0.125 ether}(1);
        main.getPublicNFT{value: 0.4 ether}(1);
        main.getCouncilWaitlistNFT{value: 0.3 ether}(3);
    }
    
    function test_GeneralWLMint() public {
        main.changeStatus(2);
        main.getGeneralWaitlistNFT{value: 0.125 ether}(1);
    }

    function testFail_AllMintsDuringGeneralWL() public {
        main.changeStatus(2);
        main.getPublicNFT{value: 0.4 ether}(1);
        main.getGeneralWaitlistNFT{value: 0.3 ether}(3);
        main.getCouncilWaitlistNFT{value: 0.2 ether}(2);

    }

    function test_PublicMint() public {
        main.changeStatus(3);
        main.getPublicNFT{value: 0.4 ether}(1);
    }

    function testFail_PublicMintLaterPhases() public {
        // should req .4 ether, not .2 or .125
        main.changeStatus(3);
        main.getPublicNFT{value:0.4 ether}(2); // this would work in 2nd phase
        main.getPublicNFT{value:0.25 ether}(2); // this would work in general phase
    }

    function test_PublicMintLaterPhase() public {
        main.changeStatus(3);
        main.getPublicNFT{value: 0.4 ether}(1);
        vm.warp(block.timestamp + 4 hours);
        main.getPublicNFT{value:0.4 ether}(2); // this would work in 2nd phase
        vm.warp(block.timestamp + 4 hours);
        main.getPublicNFT{value:0.25 ether}(2); // this would work in general phase
        // tests first, second, and general phase
    }

    function testFail_PublicMintSecondPhase() public {
        main.changeStatus(3);
        vm.warp(block.timestamp + 4 hours);
        main.getPublicNFT{value: 0.4 ether}(1); // should revert, this is first phase price
        main.getPublicNFT{value: 0.25 ether}(2); // revert, general phase price.
    }

    function testFail_PublicMintGeneralPhase() public {
        main.changeStatus(3);
        vm.warp(block.timestamp + 8 hours); 
        main.getPublicNFT{value: 0.4 ether}(1); // first phase
        main.getPublicNFT{value:0.4 ether}(2); // second phase
    }

    function testFail_getGenTwoWithoutAnyBalance() public {
        main.getGenTwo(2); // dont have any balance
    }

    function test_burnAGen1() public {
        main.changeStatus(3);
        vm.warp(block.timestamp + 8 hours);
        main.getPublicNFT{value:0.25 ether}(2); // this would work in general phase - should be 20 after this
        uint neww = main.getClaimable();
        require(neww > 19 ether, "BOOM");
        main.burnGen1(0);
        main.redeemReward();
        require(yield.balanceOf(address(this)) >= 120 ether, "Less amount"); // should be 120
        main.getGenTwo(1);
    }

    function test_Withdraw() public {
        main.changeStatus(3);
        vm.warp(block.timestamp + 8 hours);
        main.getPublicNFT{value:1 ether}(8); // this would work in general phase - should be 20 after this
        main.withdraw();
        //require(address(this).balance == 1 ether, "incorrect");
    }

    function testGetClaimable() public view {
        main.getClaimable();
    }

    function testWhilePaused() public {
        main.changeStatus(3);
        vm.warp(block.timestamp + 8 hours);
        main.getPublicNFT{value:1 ether}(8);
        main.changeStatus(4); // now paused
        main.changeStatus(3);
        vm.warp(block.timestamp + 8 hours);
        main.getPublicNFT{value:1 ether}(8);
    }

    function testTransfer() public {
        main.changeStatus(3);
        vm.warp(block.timestamp + 8 hours);
        main.getPublicNFT{value:1 ether}(8);
        main.transferFrom(address(this), address(0x6cB5FceFa0037c373aD1Ec7717874117D353bF49), 7);
        main.safeTransferFrom(address(this), address(0x6cB5FceFa0037c373aD1Ec7717874117D353bF49), 6);
    }

    /** function testMaxGeneralMint() public { this succeeds
        main.changeStatus(3);
        for (uint i = 0; i < 11111; i++) {
            main.getPublicNFT{value: 0.4 ether}(1);
        } // should work, 11112 should not 
        require(main.totalSupply() == 11111, "WRONG TOTAL SUPPLY");
    }
    **/

    /** function testFailMaxGeneralMint() public { this succeeds
        main.changeStatus(3);
        for (uint i = 0; i < 11112; i++) {
            main.getPublicNFT{value: 0.4 ether}(1);
        } // 11112 should not work
    }
    **/

    function testMint10AndGetGen2() public {
        main.changeStatus(3);
        main.getPublicNFT{value: 4 ether}(10);
        main.redeemReward();
        main.getGenTwo(1);
    }

    function testFailMint9AndGetGen2() public {
        main.changeStatus(3);
        main.getPublicNFT{value: 3.6 ether}(9);
        main.redeemReward();
        main.getGenTwo(1);
    }

    function testMint20AndGetGen2() public {
        main.changeStatus(3);
        main.getPublicNFT{value: 8 ether}(20);
        main.redeemReward();
        main.getGenTwo(1);
    }

    function testPlanarBal() public {
        address[6] memory send = [
            address(this),
            address(this),
            address(this),
            address(this),
            address(this),
            address(this)
        ];
        main.claimPlanarBal(send); //test
    }

    receive() external payable {}

}

    

    /**
        claimplanarBal + planarIds
        merkle proofs - there are 2 merkle roots - councilWL + generalWL - deploy on testnet
        
        OpenSea specific stuff for deployment
        Reveal URI - setBaseURI when ready or avery on backend - do we want a provenanceHash
     */

    /**
    82476994283048407923634290126317238187642587124158938589168337524286338105358
    82476994283048407923634290126317238187642587124158938589168337519888291594254
    82476994283048407923634290126317238187642587124158938589168337522087314849806
    82476994283048407923634290126317238187642587124158938589168337520987803222030
    82476994283048407923634290126317238187642587124158938589168337523186826477582
    82476994283048407923634290126317238187642587124158938589168337518788779966478
    
    
    
     */