import "dapple/test.sol";
import "./ProofLib.sol";

contract ProofLibInterface {
  using ProofLib for ProofLib.Proof;
  ProofLib.Proof proof;

  function ProofLibInterface(){
    proof.newChallenge(this,this,0x0, 0x6d29f6dd1270e49744bd5377ec86395b2de2abbe54bae16281b8e39b35538dcd, 7, 5);
  }

  function challenge(bool correct){
    proof.challenge(correct);
  }

  function respond(bytes32 hash){
    proof.respond(hash);
  }

  function finalize() returns (bool) {
    return proof.finalize();
  }

  function getProof() returns(uint,uint,bytes32,bytes32,bytes32){
    return proof.getProof();
  }

}

contract ProofLibTest is Test{
  ProofLibInterface proof;
  Tester proxy_tester;

  function setUp(){
    proof = new ProofLibInterface();
    proxy_tester = new Tester();
    proxy_tester._target(proof);
  }

  function testResultNotZero(){
    var (, result) = proof.getProof();
    assertTrue(result != 0);
  }

  function testChallengeFinalize(){

    proof.respond(0x356e5a2cc1eba076e650ac7473fccc37952b46bc2e419a200cec0c451dce2336);
    var (li,ri,lv,cv,rv) = proof.getProof();
    assertTrue(cv == 0x356e5a2cc1eba076e650ac7473fccc37952b46bc2e419a200cec0c451dce2336, cv);

    proof.challenge(true);
    (li,ri,lv,cv,rv) = proof.getProof();
    assertTrue(lv == 0x356e5a2cc1eba076e650ac7473fccc37952b46bc2e419a200cec0c451dce2336 && cv == 0);

    proof.respond(0xf2e59013a0a379837166b59f871b20a8a0d101d1c355ea85d35329360e69c000);
    (li,ri,lv,cv,rv) = proof.getProof();
    assertTrue(li == 5);

    assertFalse(proof.finalize());

  }

}
