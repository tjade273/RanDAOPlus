import "ProofLib.sol";

contract RanDAOPlus{
  using ProofLib for ProofLib.Proof;


  uint constant timeout = 10;

  mapping(uint => bytes32) finalizedRandomNumbers; //Maps block numbers to random numbers: One random number is generated per block

  ProofLib proofLib;

  struct Proposal {
    uint block;
    bytes32 proposal;
    uint deposit;
    address depositor;
    mapping(address => ProofLib.Proof) challenges;
    bool disproven;
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

  mapping(uint => PendingBlock) pending;

  function RanDAOPlus(address proof){
    proofLib = ProofLib(proof);
  }

  function submitProposal(uint block, bytes32 proposal){
    if(finalizedRandomNumbers[block] != 0 || pending[block].blockNumber == 0) throw;

    Proposal prop = pending[block].proposals[msg.sender];
    prop.block = block;
    prop.proposal = proposal;
    prop.deposit = msg.value;
    prop.depositor = msg.sender;

    pending[block].depositTotals[proposal] += msg.value;

    if(pending[block].depositTotals[proposal] > pending[block].depositTotals[pending[block].topProposal] && pending[block].depositTotals[proposal] > pending[block].depositLimit){
      pending[block].topProposal = proposal;
      pending[block].timer = block + timeout;
    }
  }

function newChallenge(uint blockNum, address defender){
   ProofLib.Proof proof = pending[blockNum].proposals[defender].challenges[msg.sender];

   proof.newChallenge(defender,msg.sender, block.blockhash(blockNum), pending[blockNum].proposals[defender].proposal, pending[blockNum].difficulty);
   pending[blockNum].depositTotals[pending[blockNum].proposals[defender].proposal] -= pending[blockNum].proposals[defender].deposit;
 }

  function challenge(uint block, address defender, bool correct){
    pending[block].proposals[defender].challenges[msg.sender].challenge(correct);
  }

  function respond(uint block, address challenger, bytes32 response){
    pending[block].proposals[msg.sender].challenges[challenger].respond(response);
  }

  function finalize(uint block, address defender, address challenger){
    bool challengeSuccessful = pending[block].proposals[defender].challenges[challenger].finalize();
    delete pending[block].proposals[defender].challenges[challenger];

    if(challengeSuccessful){
      challenger.send(pending[block].proposals[defender].deposit * 2);
      pending[block].proposals[defender].disproven = true;
    }
    else{
      defender.send(pending[block].proposals[defender].deposit);
    }
  }

  function finalizeNumber(uint blockNum){
    if(pending[blockNum].topProposal != 0 && pending[blockNum].timer <= block.number){
      finalizedRandomNumbers[blockNum] = pending[blockNum].topProposal;
      delete pending[blockNum];
    }
  }
}
