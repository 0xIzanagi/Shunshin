// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import {Gauge} from "../src/Marketplace/Gauge.sol";
import {Voter} from "../src/Marketplace/Voter.sol";
import {VotingEscrow} from "../src/Marketplace/VotingEscrow.sol";
import {Bribe} from "../src/Marketplace/Bribe.sol";
import {ERC20Mock} from "oz/mocks/token/ERC20Mock.sol";

contract MarketPlaceTest is Test {
    Gauge public gauge;
    ERC20Mock public mock;
    ERC20Mock public mockReward;

    function setUp() public {
        mock = new ERC20Mock();
        mockReward = new ERC20Mock();
        gauge = new Gauge(address(mock), address(mockReward), address(0));
    }
}
