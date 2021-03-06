Feature: Hand overs and take backs

  Model test (class methods)

  @rack
  Scenario: Hand overs are related to approved contracts
    Given there are "hand over" visits
    Then the associated contract of each such visit must be "approved"
    And each of the reservations of such contract must also be "approved"

  @rack
  Scenario: Take backs are related to signed contracts
    Given there are "take back" visits
    Then the associated contract of each such visit must be "signed"
    And at least one line of such contract must also be "signed"
    And the other reservations of such contract must be "closed"
