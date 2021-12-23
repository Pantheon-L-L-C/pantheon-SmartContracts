// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.11;

import "../../lib/ds-test/src/test.sol";
import "../gen2.sol";
import "../main.sol";
import "../token.sol";
import "../../lib/openzeppelin-contracts/contracts/token/ERC721/utils/ERC721Holder.sol";

contract ContractTest is DSTest, ERC721Holder {
    Main main;
    YieldToken yield;
    Gen2 gen2;

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
        
    }

}
    

    /**
        can be tested in phases:
        // start time for publicNFT 

        pre-launch, council WL, generalWL, paused

        getNFT function in each phase

        getpublicNFT
        transferFrom
        safeTransferFrom
        claimPlanarBal?

        getClaimable from token.sol
        maxMint for gen1 and gen2

        mint 10 and then claim gen2
        mint 9 and then claim gen2 - should fail not 10



        there are 2 merkle roots - councilWL + generalWL and then the
        sponsorship one
        
        test sponsorship via hardhat
    
    
     */

    /**
    82476994283048407923634290126317238187642587124158938589168337524286338105358
    82476994283048407923634290126317238187642587124158938589168337519888291594254
    82476994283048407923634290126317238187642587124158938589168337522087314849806
    82476994283048407923634290126317238187642587124158938589168337520987803222030
    82476994283048407923634290126317238187642587124158938589168337523186826477582
    82476994283048407923634290126317238187642587124158938589168337518788779966478
    
    
    
     */