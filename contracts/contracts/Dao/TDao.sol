// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TimestampGovernorSettings.sol";
import "./TimestampGovernorCompatibilityBravo.sol";
import "./TimestampGovernorVotes.sol";
import "./TimestampGovernorVotesQuorumFraction.sol";
import "./TimestampGovernorTimelockControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../common/AdminControlledUpgradeable.sol";

contract TDao is TimestampGovernorCompatibilityBravo, TimestampGovernorVotes, TimestampGovernorVotesQuorumFraction, TimestampGovernorSettings, TimestampGovernorTimelockControl, AdminControlledUpgradeable {
    uint256 constant UNPAUSED_ALL = 0;
    uint256 constant PAUSED_PROPOSE = 1 << 0;
    uint256 constant PAUSED_QUEUE = 1 << 1;
    uint256 constant PAUSED_EXECUTE = 1 << 2;
    uint256 constant PAUSED_CANCEL = 1 << 3;
    uint256 constant PAUSED_VOTE = 1 << 4;
    uint256 constant public proposalMaxOperations = 10; // 10 actions
    // uint256 public constant MIN_VOTING_DELAY = 1;
    // uint256 public constant MAX_VOTING_DELAY = 1;//40320, About 1 week
    // uint256 public constant MIN_VOTING_PERIOD = 1;
    // uint256 public constant MAX_VOTING_PERIOD = 1;//80640; About 2 weeks
    uint256 public constant MIN_QUORUM_NUMERATOR = 50;
    uint256 public minVoteDelay;
    uint256 public maxVoteDelay;
    uint256 public minVotePeriod;
    uint256 public maxVotePeriod;

    constructor(IVotes vote_, uint256 voteDelay_, uint256 votePeriod_, uint256 quorumNumerator_, TimelockController timelock_, 
        address owner_, uint256 minVoteDelay_, uint256 maxVoteDelay_, uint256 minVotePeriod_, uint256 maxVotePeriod_)
        TimestampGovernor("TDao")
        TimestampGovernorVotes(vote_)
        TimestampGovernorSettings(voteDelay_, votePeriod_, 1)
        TimestampGovernorVotesQuorumFraction(quorumNumerator_)
        TimestampGovernorTimelockControl(timelock_)
        initializer
    {
        require(Address.isContract(address(vote_)), "voter token must be existed");
        require(quorumNumerator_ != 0, " quorum numerator can not be 0");
        require(Address.isContract(address(timelock_)), "time clock controller must be existed");
        require(maxVoteDelay_ >= minVoteDelay_, "min of vote delay must less than max of vote delay");
        require(voteDelay_ >= minVoteDelay_ && voteDelay_ <= maxVoteDelay_, "invalid vote delay");
        require(maxVotePeriod_ >= minVotePeriod_, "min of vote period must less than max of vote period");
        require(votePeriod_ >= minVotePeriod_ && votePeriod_ <= maxVotePeriod_, "invalid vote period");
        minVoteDelay = minVoteDelay_;
        maxVoteDelay = maxVoteDelay_;
        minVotePeriod = minVotePeriod_;
        maxVotePeriod = maxVotePeriod_;

        _setRoleAdmin(CONTROLLED_ROLE, OWNER_ROLE);
        _setRoleAdmin(BLACK_ROLE, ADMIN_ROLE);

        _grantRole(OWNER_ROLE, owner_);
        _grantRole(ADMIN_ROLE, _msgSender());

        _AdminControlledUpgradeable_init(_msgSender(), 0);
    }

    function proposalThreshold() 
        public 
        view 
        override(TimestampGovernor, TimestampGovernorSettings)
        returns (uint256) 
    {
        return TimestampGovernorSettings.proposalThreshold();
    }

    function setProposalThreshold(uint256 newProposalThreshold) 
        public 
        override onlyGovernance 
    {
        require(newProposalThreshold >= 1, "proposalThreshold can not less than 1");
        bytes memory  payload = abi.encodeWithSignature("getMaxPersonalVotes()");
        (bool success, bytes memory result) = address(token).staticcall(payload);
        require(success, "fail to call getMaxPersonalVotes");
        uint256 threshold = abi.decode(result,(uint256));
        require(newProposalThreshold <= threshold, "threshold is overflow");
        TimestampGovernorSettings.setProposalThreshold(newProposalThreshold);
    }

    function setVotingDelay(uint256 newVotingDelay) 
        public 
        override onlyGovernance 
    {
        // require(newVotingDelay >= MIN_VOTING_DELAY && newVotingDelay <= MAX_VOTING_DELAY, "vote delay is out of range");
        require(newVotingDelay >= minVoteDelay && newVotingDelay <= maxVoteDelay, "vote delay is out of range");
        _setVotingDelay(newVotingDelay);
    }

    /**
     * @dev Update the voting period. This operation can only be performed through a governance proposal.
     *
     * Emits a {VotingPeriodSet} event.
     */
    function setVotingPeriod(uint256 newVotingPeriod) 
        public 
        override onlyGovernance 
    {
        //require(newVotingPeriod >= MIN_VOTING_PERIOD && newVotingPeriod <= MAX_VOTING_PERIOD, "vote period is out of range");
        require(newVotingPeriod >= minVotePeriod && newVotingPeriod <= maxVotePeriod, "vote period is out of range");
        _setVotingPeriod(newVotingPeriod);
    }

    function updateQuorumNumerator(uint256 newQuorumNumerator) 
        external
        override onlyGovernance 
    {
        require(newQuorumNumerator >= MIN_QUORUM_NUMERATOR, "quorumNumerator is too small");
        _updateQuorumNumerator(newQuorumNumerator);
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, TimestampGovernorVotesQuorumFraction)
        returns (uint256)
    {
        return (token.getPastTotalSupply(blockNumber) * quorumNumerator() + quorumDenominator() - 1) / quorumDenominator();
    }

    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IGovernor, TimestampGovernorVotes)
        returns (uint256)
    {
        return TimestampGovernorVotes.getVotes(account, blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(TimestampGovernor, IGovernor, TimestampGovernorTimelockControl)
        returns (ProposalState)
    {
        return TimestampGovernorTimelockControl.state(proposalId);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public
        override(TimestampGovernor, TimestampGovernorCompatibilityBravo, IGovernor) accessable_and_unpauseable(BLACK_ROLE, PAUSED_PROPOSE)
        returns (uint256)
    {
        require(targets.length <=  proposalMaxOperations, "too many actions");
        for (uint256 i = 0; i < targets.length; i++) {
            require(Address.isContract(targets[i]), "invalid contract");
        }
        return TimestampGovernorCompatibilityBravo.propose(targets, values, calldatas, description);
    }

    function propose(address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) 
        public 
        override accessable_and_unpauseable(BLACK_ROLE, PAUSED_PROPOSE)
        returns (uint256)
    {
        require(targets.length <=  proposalMaxOperations, "too many actions");
        for (uint256 i = 0; i < targets.length; i++) {
            require(Address.isContract(targets[i]), "invalid contract");
        }
        return TimestampGovernorCompatibilityBravo.propose(targets, values, signatures, calldatas, description);
    }

    function queue(uint256 proposalId) 
        public
        override accessable_and_unpauseable(BLACK_ROLE, PAUSED_QUEUE)
    {
        TimestampGovernorCompatibilityBravo.queue(proposalId);
    }

    function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash) 
        public
        override(TimestampGovernorTimelockControl, IGovernorTimelock) accessable_and_unpauseable(BLACK_ROLE, PAUSED_QUEUE)
        returns (uint256)
    {
        return TimestampGovernorTimelockControl.queue(targets, values, calldatas, descriptionHash);
    }

    function execute(uint256 proposalId) 
        public
        payable
        override accessable_and_unpauseable(BLACK_ROLE, PAUSED_EXECUTE)
    {
        TimestampGovernorCompatibilityBravo.execute(proposalId);
    }

    function cancel(uint256 proposalId) 
        public
        override accessable_and_unpauseable(BLACK_ROLE, PAUSED_CANCEL)
    {
        TimestampGovernorCompatibilityBravo.cancel(proposalId);
    }

    function castVote(uint256 proposalId, uint8 support) 
        public 
        override(TimestampGovernor, IGovernor) accessable_and_unpauseable(BLACK_ROLE, PAUSED_VOTE)
        returns (uint256) 
    {
        return TimestampGovernor.castVote(proposalId, support);
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(TimestampGovernor, TimestampGovernorTimelockControl)
    {
        TimestampGovernorTimelockControl._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(TimestampGovernor, TimestampGovernorTimelockControl)
        returns (uint256)
    {
        return TimestampGovernorTimelockControl._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(TimestampGovernor, TimestampGovernorTimelockControl)
        returns (address)
    {
        return TimestampGovernorTimelockControl._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(TimestampGovernor, IERC165, TimestampGovernorTimelockControl, AccessControl)
        returns (bool)
    {
        return TimestampGovernorTimelockControl.supportsInterface(interfaceId) || 
               TimestampGovernor.supportsInterface(interfaceId) || 
               AccessControl.supportsInterface(interfaceId);
    }
}