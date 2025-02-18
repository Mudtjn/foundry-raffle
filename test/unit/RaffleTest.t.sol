// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol"; 
import {HelperConfig} from "script/HelperConfig.s.sol"; 
import {Raffle} from "src/Raffle.sol"; 
contract RaffleTest is Test {

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subId;
    uint32 callbackGasLimit; 
    Raffle public raffle; 
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("player_1"); 
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether; 


    function setUp() external {
        DeployRaffle deployer = new DeployRaffle(); 
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee; 
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subId = config.subId;
        callbackGasLimit = config.callbackGasLimit;  
    }

    function testRaffleInitializedInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }
}