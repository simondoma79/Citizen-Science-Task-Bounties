import { describe, expect, it, beforeAll } from 'vitest';
import { Cl } from '@stacks/transactions';
import { initSimnet } from '@hirosystems/clarinet-sdk';

let simnet: any;

beforeAll(async () => {
  simnet = await initSimnet();
});

describe('Citizen Science Task Bounties - Categories System', () => {

  it('can create task with category and submit observation', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    // Create a task with BIOLOGY category
    const createTaskResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'create-task',
      [
        Cl.stringUtf8('Bird Count'),
        Cl.stringUtf8('Count birds in your backyard'),
        Cl.uint(100),
        Cl.uint(30),
        Cl.uint(5),
        Cl.uint(0),
        Cl.stringAscii('BIOLOGY')
      ],
      deployer
    );

    expect(createTaskResult.result).toBeOk(Cl.uint(1));

    // Submit an observation
    const submitResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'submit-observation',
      [
        Cl.uint(1),
        Cl.stringUtf8('Observed 5 sparrows')
      ],
      user1
    );

    expect(submitResult.result).toBeOk(Cl.bool(true));
  });

  it('validates category management functions', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;
    const user1 = accounts.get('wallet_1')!;

    // Test getting default category
    const getCategoryResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'get-category',
      [Cl.stringAscii('BIOLOGY')],
      deployer
    );
    expect(getCategoryResult.result).toBeDefined();

    // Test checking category activity
    const isActiveResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'is-category-active',
      [Cl.stringAscii('BIOLOGY')],
      deployer
    );
    expect(isActiveResult.result).toBeBool(true);

    // Test adding new category (only owner)
    const addCategoryResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'add-category',
      [
        Cl.stringAscii('MARINE_BIOLOGY'),
        Cl.stringUtf8('Study of marine life and ecosystems')
      ],
      deployer
    );
    expect(addCategoryResult.result).toBeOk(Cl.bool(true));

    // Test non-owner cannot add category
    const unauthorizedResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'add-category',
      [
        Cl.stringAscii('UNAUTHORIZED'),
        Cl.stringUtf8('This should fail')
      ],
      user1
    );
    expect(unauthorizedResult.result).toBeErr(Cl.uint(100)); // err-owner-only
  });

  it('tracks category statistics correctly', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;

    // Create a task in BIOLOGY category
    const createTaskResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'create-task',
      [
        Cl.stringUtf8('Plant Growth Study'),
        Cl.stringUtf8('Monitor plant growth over 4 weeks'),
        Cl.uint(200),
        Cl.uint(50),
        Cl.uint(3),
        Cl.uint(0),
        Cl.stringAscii('BIOLOGY')
      ],
      deployer
    );
    expect(createTaskResult.result).toBeOk(Cl.uint(1));

    // Check category statistics
    const statsResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'get-category-stats',
      [Cl.stringAscii('BIOLOGY')],
      deployer
    );
    expect(statsResult.result).toBeTuple({
      'total-tasks': Cl.uint(1),
      'active-tasks': Cl.uint(1),
      'completed-tasks': Cl.uint(0)
    });

    // Test task category validation
    const taskInCategoryResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'is-task-in-category',
      [Cl.uint(1), Cl.stringAscii('BIOLOGY')],
      deployer
    );
    expect(taskInCategoryResult.result).toBeBool(true);

    // Test with wrong category
    const wrongCategoryResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'is-task-in-category',
      [Cl.uint(1), Cl.stringAscii('PHYSICS')],
      deployer
    );
    expect(wrongCategoryResult.result).toBeBool(false);
  });

  it('handles invalid category scenarios', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;

    // Try to create task with invalid category
    const invalidCategoryResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'create-task',
      [
        Cl.stringUtf8('Invalid Task'),
        Cl.stringUtf8('This should fail'),
        Cl.uint(100),
        Cl.uint(30),
        Cl.uint(5),
        Cl.uint(0),
        Cl.stringAscii('INVALID_CATEGORY')
      ],
      deployer
    );
    expect(invalidCategoryResult.result).toBeErr(Cl.uint(108)); // err-invalid-category

    // Test category toggle functionality
    const toggleResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'toggle-category-status',
      [Cl.stringAscii('BIOLOGY')],
      deployer
    );
    expect(toggleResult.result).toBeOk(Cl.bool(true));

    // Try to create task with deactivated category
    const inactiveCategoryResult = simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'create-task',
      [
        Cl.stringUtf8('Biology Task'),
        Cl.stringUtf8('Should fail with inactive category'),
        Cl.uint(100),
        Cl.uint(30),
        Cl.uint(5),
        Cl.uint(0),
        Cl.stringAscii('BIOLOGY')
      ],
      deployer
    );
    expect(inactiveCategoryResult.result).toBeErr(Cl.uint(110)); // err-category-inactive
  });

  it('validates task category retrieval functions', () => {
    const accounts = simnet.getAccounts();
    const deployer = accounts.get('deployer')!;

    // Create a task first
    simnet.callPublicFn(
      'Citizen-Science-Task-Bounties',
      'create-task',
      [
        Cl.stringUtf8('Test Task'),
        Cl.stringUtf8('Test Description'),
        Cl.uint(100),
        Cl.uint(30),
        Cl.uint(5),
        Cl.uint(0),
        Cl.stringAscii('ENVIRONMENTAL')
      ],
      deployer
    );

    // Test get task category
    const categoryResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'get-task-category',
      [Cl.uint(1)],
      deployer
    );
    expect(categoryResult.result).toBeSome(Cl.stringAscii('ENVIRONMENTAL'));

    // Test count tasks in category
    const countResult = simnet.callReadOnlyFn(
      'Citizen-Science-Task-Bounties',
      'count-tasks-in-category',
      [Cl.stringAscii('ENVIRONMENTAL')],
      deployer
    );
    expect(countResult.result).toBeUint(1);
  });
});
