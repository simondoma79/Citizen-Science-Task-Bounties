import { Clarinet, Tx, Chain, Account, types } from '@stacks/transactions';

Clarinet.test({
  name: "Ensure can create task and submit observation",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get("deployer")!;
    const user1 = accounts.get("wallet_1")!;

    let block = chain.mineBlock([
      Tx.contractCall(
        "citizen-science-task-bounties",
        "create-task",
        [
          types.utf8("Bird Count"),
          types.utf8("Count birds in your backyard"),
          types.uint(100),
          types.uint(30),
          types.uint(5)
        ],
        deployer.address
      )
    ]);
    block.receipts[0].result.expectOk().expectUint(1);

    block = chain.mineBlock([
      Tx.contractCall(
        "citizen-science-task-bounties",
        "submit-observation",
        [
          types.uint(1),
          types.utf8("Observed 5 sparrows")
        ],
        user1.address
      )
    ]);
    block.receipts[0].result.expectOk().expectBool(true);
  }
});
