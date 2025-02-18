// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19; 

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol"; 
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol"; 
import {DevOpsTools} from "@foundry-devops/DevOpsTools.sol"; 

contract CreateSubscription is Script{

    function createSubscriptionUsingConfig() public returns(uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        (uint256 subId, ) = createSubscription(vrfCoordinator);  
        return (subId, vrfCoordinator); 
    }

    function createSubscription(address vrfCoordinator) public returns(uint256, address) {  
        console.log("Creating subscription for vrfCoordinator: ", vrfCoordinator); 
        vm.startBroadcast();
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();  
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, msg.sender); 
        vm.stopBroadcast(); 
        console.log("Created Subscription: subid is ", subId); 
        return (subId, vrfCoordinator); 
    
    }

    function run() external {
        createSubscriptionUsingConfig();
    }   

}

contract FundSubscription is CodeConstants, Script {

    error FundSubscription__InvalidChainId(); 
    uint256 public constant FUND_AMOUNT = 0.1 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subId;
        address linkToken = helperConfig.getConfig().link;

        if(subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription(); 
            (subscriptionId, vrfCoordinator) = createSubscription.createSubscription(vrfCoordinator);
        }

        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken) public {
        console.log("Funding subscription for vrfCoordinator: ", vrfCoordinator); 
        console.log("Funding subscription for subscription id: ", subscriptionId); 

        if(block.chainid == ETH_SEPOLIA_CHAIN_ID){  
            console.log(LinkToken(linkToken).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(linkToken).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast();
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        } else if(block.chainid == ETH_ANVIL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT); 
            vm.stopBroadcast(); 
        } else {
            revert FundSubscription__InvalidChainId(); 
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subId;
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subscriptionId);
    }

    function addConsumer(address contractToAddtoVrf, address vrfCoordinator, uint256 subscriptionId ) public {
        console.log("Adding consumer to vrfCoordinator: ", vrfCoordinator); 
        console.log("Adding consumer to subscription id: ", subscriptionId);
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subscriptionId, contractToAddtoVrf);
        vm.stopBroadcast();
    }   

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid); 
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}