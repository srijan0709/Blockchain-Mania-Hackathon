// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import"./DisasterDataExample.sol";


contract cropInsurance {


    // using SafeMathChainlink for uint;

    // struct PremiumDeposited{
    //     uint amount;
    //     uint date;            // the day of PREMIUM GIVEN
    // }
    struct farmerData{
        address addressFarmer;

        // PremiumDeposited[] PremiumsWithDate;        ///trying mapping for premiium deposited

        // mapping(uint => uint) DateWithPremium;

        uint256[] premiums;
        uint256[] dates;
        uint[] factorForPremium;   // /// can we make it decimnal or not needed as lowest is wei and it is very small so wont make much of a difference

        string city;

        uint calculatedPayout;
        uint dateRegitered;
        uint lastPayoutCalcDate;

        uint totalPremiumAdded;
        uint thisFarmersFactorSum;


    }

    // farmerData[] AllFarmers;

    mapping (address => farmerData) public AllFarmers;
    mapping (address => bool) public ifRegistered;
    address[] AllFarmersAddress ;     /// as we cant iterate over mapping 

    uint LastDayInsuranceCalc ;
    uint totalSumFactor;


    uint numberOfTimesInsurancePayoutCalculated ;
    uint minimumDaysAfterNewPersonCanRedeem = 0 days;
    uint minimumDaysAfterInterestCalcAgainDone = 0 days;
    uint minimumPayoutWhichCanBeClaimied = 0 wei;
    uint minimumPremiumThatCanBeContributed = 100 wei;

    modifier CheckIfRegistered(address _address){
        require(ifRegistered[_address] == true , "Please register First" );
            _;
        
    }

    function RegisteringOfFarmer(string memory city ) external{
        require(ifRegistered[msg.sender] == false) ;     // to register only once

        ifRegistered[msg.sender] = true;
        address addressFarmer = msg.sender;
        // PremiumDeposited[] memory PremiumsWithDate;
        // PremiumsWithDate.push(PremiumDeposited( msg.value , block.timestamp));           /// sampple array 
        
        // mapping(uint => uint) storage DateWithPremium ;
        // DateWithPremium[block.timestamp] = msg.value;

        uint[] memory premiums;
        // premiums.push(msg.value);

        uint[] memory dates;
        // dates.push(block.timestamp);

        uint[] memory factorForPremium;        /// can we make it decimnal or not needed as lowest is wei and it is very small so wont make much of a difference

        farmerData memory currFarmer = farmerData(addressFarmer ,premiums, dates, factorForPremium, city , 0 , block.timestamp, block.timestamp ,0 ,0 );
        AllFarmers[addressFarmer] = currFarmer;
        AllFarmersAddress.push(msg.sender);



    }

    function DepositingPremium() external payable CheckIfRegistered(msg.sender){
        require(msg.value >= minimumPremiumThatCanBeContributed, "Increase the premium amount");       // to deal with a minimum premium amount
        AllFarmers[msg.sender].premiums.push(msg.value);
        AllFarmers[msg.sender].dates.push(block.timestamp);
        AllFarmers[msg.sender].totalPremiumAdded += msg.value;

    }

    // function ClaimingInsurance() external payable CheckIfRegistered(msg.sender) {
    //     require(block.timestamp > AllFarmers[msg.sender].dateRegitered + minimumDaysAfterNewPersonCanRedeem , "Please wait for some more time before claiming insurance");
    //     if(block.timestamp < LastDayInsuranceCalc + minimumDaysAfterInterestCalcAgainDone){
    //         require(AllFarmers[msg.sender].calculatedPayout != 0 , "No Outstanding Payout Left");
    //         require(AllFarmers[msg.sender].calculatedPayout >= minimumPayoutWhichCanBeClaimied);
    //         // (bool callSuccess , ) = payable(msg.sender).call{value: address(this).balance}("");
    //         // require(callSuccess, "Call Failed");
    //         payable(msg.sender).transfer(AllFarmers[msg.sender].calculatedPayout);
    //         AllFarmers[msg.sender].calculatedPayout = 0;
    //     }


    // }

    function CalculatePayoutAmount() external CheckIfRegistered(msg.sender){
        require(AllFarmers[msg.sender].totalPremiumAdded != 0 , "First Add Some Premium" );
        require(block.timestamp >= AllFarmers[msg.sender].dateRegitered + minimumDaysAfterNewPersonCanRedeem , "Wait For some more time before calculating payout");
        require(block.timestamp >= LastDayInsuranceCalc + minimumDaysAfterInterestCalcAgainDone, "Inusrance Calculated, check Payout ammount, For Calculation of Payout money again , come later");

        AllfactorCalculation();

        uint moneyInContract = address(this).balance;

        for(uint i = 0 ; i < AllFarmersAddress.length ; i ++)
        {
            AllFarmers[AllFarmersAddress[i]].calculatedPayout += (moneyInContract * AllFarmers[AllFarmersAddress[i]].thisFarmersFactorSum) / totalSumFactor;    
        }

    } 

    function withdrawCalculatedPayoutMoney() external payable CheckIfRegistered(msg.sender){
        require(AllFarmers[msg.sender].calculatedPayout != 0 , "No Money for Payout");

        payable(msg.sender).transfer(AllFarmers[msg.sender].calculatedPayout);

        uint[] memory premiums;
        uint[] memory dates;
        uint[] memory factorForPremium; 

        farmerData memory currFarmer = farmerData(msg.sender ,premiums, dates, factorForPremium, AllFarmers[msg.sender].city , 0, AllFarmers[msg.sender].dateRegitered , block.timestamp ,0  , 0 );
        AllFarmers[msg.sender] = currFarmer;

    }
    function calculateSeverity( string memory _city) internal returns(uint){
        DisasterData dataFeed = DisasterData(0xADC6635808229889631E28dcEdeF566e8f30027D);
        return dataFeed.getAccumulatedSeverity(_city);
    }


    function AllfactorCalculation() internal {
        for(uint i = 0 ; i < AllFarmersAddress.length ; i++)
        {

            // Check Draught for that i 
            // figure out severtiy

            // uint currSeverity;
            uint currSeverity = calculateSeverity(AllFarmers[AllFarmersAddress[i]].city);

            for(uint j = 0 ; j < uint(AllFarmers[AllFarmersAddress[i]].premiums.length) ; j++)
            {
                uint currFactor = singleFactorCalculation(AllFarmers[AllFarmersAddress[i]].premiums[j] , AllFarmers[AllFarmersAddress[i]].dates[j] , currSeverity);
                AllFarmers[AllFarmersAddress[i]].factorForPremium.push(currFactor);
                AllFarmers[AllFarmersAddress[i]].thisFarmersFactorSum+= currFactor;
                totalSumFactor+= currFactor;
            }
        }
    }
    
    function singleFactorCalculation(uint _premium , uint _date ,uint _severity) internal returns(uint)
    {
        uint TimeForWhichkept = block.timestamp - _date;
        return (_premium * 2)  * (TimeForWhichkept * 1) * (_severity ** 1);
    }




}
