//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{
    function CreateSubscriptionUsingConfig() public returns(uint64) {
     //use helperconfig
    HelperConfig helperConfig = new HelperConfig(); 
    //get active network information,only need coordinator here
      (, , , , ,address vrfCoordinatorV2, ,uint256 deployerKey) = helperConfig.activeNetworkConfig();
      return createSubscription(vrfCoordinatorV2, deployerKey);
    }

    function createSubscription(address vrfCoordinator, uint256 deployerKey) public returns (uint64) {
       console.log("Creating subscriotion on ChainId:", block.chainid);
       vm.startBroadcast(deployerKey);
       uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
       vm.stopBroadcast();
       console.log("Your sub ID is", subId);
       console.log("please update subscriptionId in HelperConfig.s.sol");
       return subId;
    }

     function run() external returns (uint64) {
        return CreateSubscriptionUsingConfig();
     }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;
    //same to above
    
    function fundSubscriptionUsingConfig() public {
        //use helperconfig
        HelperConfig helperConfig = new HelperConfig(); 
        //get active network information,only need coordinator here
        //need subId,cuz we should fund here
        (uint64 subId, , , , ,address vrfCoordinatorV2, address link, uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinatorV2, subId, link, deployerKey);
    }

    function fundSubscription(address vrfCoordinatorV2, uint64 subId, address link, uint256 deployerKey) public{
        console.log("Funding subscription: ", subId);
        console.log("Using vrfCoordinator: ", vrfCoordinatorV2);
        console.log("On ChainID: ", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinatorV2).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log(LinkToken(link).balanceOf(msg.sender));
            console.log(msg.sender);
            console.log(LinkToken(link).balanceOf(address(this)));
            console.log(address(this));
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(
                vrfCoordinatorV2,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }
    
    function run() external {
          fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    //the rafle contract is cool work with suscription ID
    function addConsumer(address raffle, address vrfCoordinator, uint64 subId, uint256 deployerKey) public{
        console.log("Adding Consumer contract", raffle);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function AddConsumerUsingConfig(address raffle) public{
        HelperConfig helperConfig = new HelperConfig();
        (uint64 subId, , , , ,address vrfCoordinatorV2, ,uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(raffle, vrfCoordinatorV2, subId, deployerKey);
    }

    function run() external{
      address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
      AddConsumerUsingConfig(raffle);
    }
    
}