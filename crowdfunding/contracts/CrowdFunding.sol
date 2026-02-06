// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract CrowdFunding is ReentrancyGuard, ERC721{

    constructor() ERC721("CrowdFunding Supporter", "CFS") {}

    enum ProjectState {
        Active,
        Successful,
        Failed
    }

    struct Project {
        uint256 projectID;
        string projectTitle;
        string projectDescription;
        address payable projectOwner;
        uint256 projectMinParticipationAmount;
        uint256 totalRaised;
        uint256 projectFundingGoal;
        uint256 deadline;
        ProjectState state;
    }

    Project[] private projectArray;

    mapping(uint256 => mapping (address => uint256)) private participantDirectory;

    uint256 private nextTokenID;
    mapping(uint256 => mapping(address => bool)) public rewardMinted;
    mapping(uint256 => uint256) public tokenProject;

    event ProjectCreated(
        uint256 indexed projectID,
        address indexed projectOwner,
        uint256 projectFundingGoal,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed projectID,
        address indexed contributor,
        uint256 amount
    );

    event FundsWithdrawn(
        uint256 indexed projectID,
        uint256 amount
    );

    event Refunded(
        uint256 indexed projectID,
        address indexed contributor,
        uint256 amount
    );

    // CREATE PROJECTS
    // Replaced memory for calldata to reduce gas cost and improve security, as call data is read-only.
    function createProject(
            string calldata _projectTitle, 
            string calldata _projectDescription,
            uint256 _projectMinParticipationAmount,
            uint256 _projectFundingGoal,
            uint256 durationDays
    ) external {
        
        require(_projectFundingGoal > 0, "Funding goal must be > 0");
        require(durationDays > 0, "Specify the duration in days");

            uint256 _projectID = projectArray.length;
            uint256 _projectTotalFundingAmount = 0;
            uint256 _projectDurationSeconds = durationDays * 86400; // Convert to seconds
            
            projectArray.push(
                Project({
                projectID: _projectID,
                projectTitle: _projectTitle,
                projectDescription: _projectDescription,
                projectOwner: payable(msg.sender),
                projectMinParticipationAmount: _projectMinParticipationAmount,
                totalRaised: _projectTotalFundingAmount,
                projectFundingGoal: _projectFundingGoal,
                deadline: block.timestamp + _projectDurationSeconds,
                state: ProjectState.Active
                })
            );


            emit ProjectCreated(
                _projectID,
                msg.sender,
                _projectFundingGoal,
                block.timestamp + _projectDurationSeconds
            );
    }

    
    function participateToProject(
        uint256 _projectID
    ) external payable nonReentrant {
        
        address _participantAddress = msg.sender;
        
        Project storage project = projectArray[_projectID];

        require(project.state == ProjectState.Active, "Project is not active");
        require((project.deadline) >= block.timestamp, "Deadline passed");
        require(msg.value >= project.projectMinParticipationAmount, 
            string.concat("The participation amount should be equal or higher than: ",
            Strings.toString(project.projectMinParticipationAmount)
            )
        );
        
        participantDirectory[_projectID][_participantAddress] += msg.value;
        project.totalRaised += msg.value;

        //Award NFT is contributed successfully
        if (!rewardMinted[_projectID][msg.sender]) {
            uint256 tokenID = ++nextTokenID;

            rewardMinted[_projectID][msg.sender] = true;
            tokenProject[tokenID] = _projectID;

            _safeMint(msg.sender, tokenID);
        }

        emit ContributionMade(_projectID, msg.sender, msg.value);
    }


    function finalizeProject(
        uint256 _projectID
    ) public {

        Project storage project = projectArray[_projectID];

        require(project.state == ProjectState.Active, "Already finalized");
        require((project.deadline) <= block.timestamp, "Deadline not reached");

        if (project.totalRaised >= project.projectFundingGoal) {
            project.state = ProjectState.Successful;
        } else {
            project.state = ProjectState.Failed;
        }
    }


    function withdrawFunds(
        uint256 _projectID
    ) external nonReentrant {
        
        Project storage project = projectArray[_projectID];

        require(msg.sender == project.projectOwner, "Just the project's owner can withdraw");

        if (project.state == ProjectState.Active) {
            finalizeProject(_projectID);
        }

        require(project.state == ProjectState.Successful, "Project failed");
        
        uint256 amountToTransfer = project.totalRaised;
        
        require(amountToTransfer > 0, "No funds to withdraw");
        
        project.totalRaised = 0;

        (bool success, ) = project.projectOwner.call{value: amountToTransfer}("");
        require(success, "ETH transfer failed");

        emit FundsWithdrawn(_projectID, amountToTransfer);
    }


    function refund(
        uint256 _projectID
    ) external nonReentrant {

        Project storage project = projectArray[_projectID];

        if (project.state == ProjectState.Active) {
            finalizeProject(_projectID);
        }

        require(project.state == ProjectState.Failed, "Refunds unavailable");

        uint256 contributed = participantDirectory[_projectID][msg.sender];
        require(contributed > 0, "No contributions shown in the project's directory");

        participantDirectory[_projectID][msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: contributed}("");
        require(success, "Refund failed");

        emit Refunded(_projectID, msg.sender, contributed);
    }


    function getProjectDetails(
        uint256 _projectID
    ) external view returns (Project memory) {
        
        return projectArray[_projectID];
    }


    function retrieveContributions(
        address _participantAddress, 
        uint256 _projectID
    ) external view returns (uint256) {

        return participantDirectory[_projectID][_participantAddress];
    }

}


    


    



