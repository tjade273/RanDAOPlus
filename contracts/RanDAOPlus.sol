import "proofLib.sol";

using ProofLib for ProofLib.Proof;

contract RanDAOPlus{
  uint constant timeout = 10;

  mapping(uint => bytes32) finalizedRandomNumbers; //Maps block numbers to random numbers: One random number is generated per block

  ProofLib proofLib;

  struct Proposal {
    uint block;
    bytes32 proposal;
    uint deposit;
    address depositor;
    mapping(address => ProofLib.Proof) challenges;
  }

  struct PendingBlock {
    uint blockNumber;
    uint difficulty;
    uint depositLimit;
    mapping(bytes32 => uint) depositTotals;
    mapping(address => Proposal) proposals;

    bytes32 topProposal;
    uint timer;
  }

  mapping(uint => pendingBlock) pending;

  function RanDAOPlus(address proof){
    proofLib = ProofLib(proof);
  }

  function submitProposal(uint block, bytes32 proposal){
    if(finalizedRandomNumbers[uint] != 0 || pending[block].blockNumber == 0) throw;

    Proposal prop = pending[block].proposals[msg.sender];
    prop.block = block;
    prop.proposal = proposal;
    prop.deposit = msg.value;
    prop.depositor = msg.sender;

    pending[block].depositTotals[proposal] += msg.value;

    if(pending[block].depositTotals[proposal] > pending[block].depositTotals[pending[block].topProposal] && pending[block].depositTotals[proposal] > pending[block].depositLimit){
      pending[block].topProposal = proposal;
      pending[block].timer = block.timestamp + timeout;
    }
  }

  function challenge(uint block, address defender){
    ProofLib.Proof proof = pending[block].proposals[defender].challenges[msg.sender];

    proof.newChallenge(defender,msg.sender, block.hash(block), pending[block].proposals[defender].proposal, pending[block].difficulty);
    pending[block].depositTotals[proposal] -= pending[block].proposals[defender].deposit;
  }

  function finalizeNumber(uint block){
    if(pending[block].topProposal.proposal != 0 && pending[block].timer <= block.number){
      finalizedRandomNumbers[block] = pending[block].topProposal;
      delete pending[block]
    }
  }


}
