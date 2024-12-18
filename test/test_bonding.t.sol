// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Bonding} from "../contracts/fun/Bonding.sol";
import {AgentToken} from "../contracts/AgentToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract BondingTest is Test {
    Bonding public bonding;
    IERC20 public assetToken;

    address public owner = 0x0551fB497B436fdBDB6109B6F8c4949C7e16b6ac;


    function setUp() public {
        vm.createSelectFork("bscTestnet",
            46566410);
        bonding = Bonding(0xb1D6C89c53A3454d73535f1ad0c96Bd87b6b343c);
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
        assetToken.approve(address(bonding), purchaseAmount);
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
        address fRouter = 0xd466efDfE7f35cAF0f6352D39330d09DA7dE03D6;
        token.approve(fRouter, amount);
        vm.prank(owner);
        bonding.sell(amount, address(token));
    }

    function test_graduate() public {
        launch();
        IERC20 token = IERC20(bonding.tokenInfos(0));
        uint256 amount = 70000 *10**18;
        vm.prank(owner);
        address fRouter = 0xd466efDfE7f35cAF0f6352D39330d09DA7dE03D6;
        assetToken.approve(fRouter, amount);
        vm.prank(owner);
        bonding.buy(amount, address(token));
    }




}
