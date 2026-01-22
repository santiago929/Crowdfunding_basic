// SPDX-License-Identifier: MIT
/// @notice This conctract creates a new crowdfunding project. All contributions will be in wei (1 ETH = 1e18 wei)
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

contract crowdFunding {

    struct Project {
        uint256 projectID;
        string projectTitle;
        string projectDescription;
        address projectOwner;
        uint256 projectParticipationAmount;
        uint256 projectTotalFundingAmount;
    }

    Project[] public projectArray;
    mapping(uint256 => mapping (address => uint256)) private participantDirectory;

    function createProject(string memory _projectTitle, 
            string memory _projectDescription,
            uint256 _projectParticipationAmount) public {
            
            uint256 _projectID = projectArray.length + 1;
            uint256 _projectTotalFundingAmount = 0;
            address _projectOwner = msg.sender;
            
            Project memory newProject = Project(_projectID,_projectTitle,
            _projectDescription,_projectOwner,
            _projectParticipationAmount, 
            _projectTotalFundingAmount);
            
            projectArray.push(newProject);
    }
    

    function participateToProject(uint256 _ProjectID) public payable {
        address _participantAddress = msg.sender;

        require(msg.value >= projectArray[_ProjectID].projectParticipationAmount, 
            string.concat("The participation amount should be equal or higher than: ",
            Strings.toString(projectArray[_ProjectID].projectParticipationAmount), " wei"));

        participantDirectory[_ProjectID][_participantAddress] += msg.value;
        projectArray[_ProjectID].projectTotalFundingAmount += msg.value;
    }


    function getProjectDetails(uint256 _projectID) public view returns (Project memory) {
        return projectArray[_projectID];
    }


    function retrieveContributions(address _participantAddress, uint256 _projectID) public view 
        virtual returns (uint256) {
        
        return participantDirectory[_projectID][_participantAddress];
    }


    function withdrawFunds(uint256 _ProjectID) public {
        uint256 amountToTransfer = projectArray[_ProjectID].projectTotalFundingAmount;
        
        require(msg.sender == projectArray[_ProjectID].projectOwner, "Just the project's owner can withdraw");
        require(amountToTransfer > 0, "No funds to withdraw");
        

        projectArray[_ProjectID].projectTotalFundingAmount = 0;
        
        payable(projectArray[_ProjectID].projectOwner).transfer(amountToTransfer);
    }

}



