// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../gen2.sol";
import "../main.sol";
import "../token.sol";

contract ContractTest is DSTest {
    Main main;
    YieldToken yield;
    Gen2 gen2;

    function setUp() public {
        bytes32 root = 0x4d32c58ef0a2d0cea440002d346d7d413c49f93ec252522642e1e4937e85089a;
        address treasury = 0x6cB5FceFa0037c373aD1Ec7717874117D353bF49;
        address planar = 0x495f947276749Ce646f68AC8c248420045cb7b5e;
        main = new Main(root, treasury, planar);
        yield = new YieldToken(address(main));
        gen2 = new Gen2(address(main));
    } 

    function testsetTokenAddyAndCouncilWL() public {
        main.setTokenAddresses(address(yield), address(gen2));
        main.changeStatus(1);
    }

    function testSuperMint() public {
        main.superMint();
    }
}
