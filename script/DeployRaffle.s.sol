//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import{Raffle} from "../src/Raffle.sol";
import{HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription,  FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script{
    function run() external returns (Raffle, HelperConfig){
      HelperConfig helperConfig = new HelperConfig();
      (
        uint64 subscriptionId,
        bytes32 gasLane,// keyHash
        uint256 interval,
        uint256 entranceFee,
        uint32 callbackGasLimit,
        address vrfCoordinatorV2,
        address link,
        uint256 deployerKey
      ) = helperConfig.activeNetworkConfig();

      if(subscriptionId == 0) {
        //we need to create a subscription
        CreateSubscription createSubscription = new CreateSubscription();//interractions.s.sol
       subscriptionId = createSubscription.createSubscription(vrfCoordinatorV2, deployerKey);

        //fund it
        FundSubscription fundSubscription = new  FundSubscription();
        fundSubscription.fundSubscription(vrfCoordinatorV2, subscriptionId, link, deployerKey);
      }

      //equal NetworkConfig config =  helperConfig.activeNetworkConfig();
      vm.startBroadcast(deployerKey);
      Raffle raffle = new Raffle(
        subscriptionId,
        gasLane,// keyHash
        interval,
        entranceFee,
        callbackGasLimit,
        vrfCoordinatorV2
      );
      vm.stopBroadcast();
      
      AddConsumer addConsumer = new AddConsumer();
      addConsumer.addConsumer(address(raffle), vrfCoordinatorV2, subscriptionId, deployerKey);
      return (raffle, helperConfig);
    }
}