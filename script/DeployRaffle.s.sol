// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol"; 

contract DeployRaffle is Script {

    function deployRaffle() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        if(config.subId == 0){
            CreateSubscription createSubscription = new CreateSubscription(); 
            (config.subId, config.vrfCoordinator) = createSubscription.createSubscription(config.vrfCoordinator);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subId, config.link);
        }

        vm.startBroadcast();
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer(); 
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subId);

        return (raffle, helperConfig);
    }

    function run() public returns (Raffle, HelperConfig) {
        return deployRaffle();
    }
}
