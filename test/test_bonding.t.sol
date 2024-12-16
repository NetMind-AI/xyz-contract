// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Bonding} from "../contracts/fun/Bonding.sol";
import {BondingProxy} from "../contracts/proxy/BondingProxy.sol";
import {AgentToken} from "../contracts/AgentToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BondingTest is Test {
    Bonding public bonding;
    IERC20 public assetToken;

    address public owner = 0x0551fB497B436fdBDB6109B6F8c4949C7e16b6ac;


    function setUp() public {
        vm.createSelectFork("bscTestnet", 46532359);
        bonding = Bonding(0x7Eae3707Ed04Fc5653d97eBB8F77816dCDE9d239);
        assetToken = IERC20(0xeE065D420621dFd98a9e5787262716143F9F60A7);
    }

    function launch() public {
        string memory _name = "CAT TOKEN";
        string memory _ticker = "CAT";
        string memory desc = "CAT was one of the first AI programs created in the mid-1960s by Joseph Weizenbaum. It simulated a psychotherapist by using pattern-matching techniques and simple scripts to engage users in therapeutic-style conversations.";
        string memory img = "https://s3.ap-southeast-1.amazonaws.com/virtualprotocolcdn/name_1a472488f8.jpeg";
        string[4] memory urls = ["https://x.com/MiladyCult", "https://t.me/CULTDOTINC", "https://www.youtube.com/watch?v=yfAD_VjGniU&list=PLQgFdvwwFhAW2mBTJUOUHtQegzgnpKFdb&index=2", "https://cult.inc/"];
        uint256 purchaseAmount = 200 *10**18;
        vm.prank(owner);
        bonding.launch(_name, _ticker, desc, img, urls, purchaseAmount);
    }

    function test_launch() public {
        launch();
    }

    function test_sell() public {
        launch();
        IERC20 token = IERC20(bonding.tokenInfos(0));
        uint256 amount = 200 *10**18;
        vm.prank(owner);
        address fRouter = 0xd68ceE0168C9A75A138700BE54B550E94E76AB4E;
        token.approve(fRouter, amount);
        vm.prank(owner);
        bonding.sell(amount, address(token));
    }

    function test_graduate() public {
        launch();
        IERC20 token = IERC20(bonding.tokenInfos(0));
        uint256 amount = 70000 *10**18;
        vm.prank(owner);
        address fRouter = 0xd68ceE0168C9A75A138700BE54B550E94E76AB4E;
        assetToken.approve(fRouter, amount);
        vm.prank(owner);
        bonding.buy(amount, address(token));
    }




}
