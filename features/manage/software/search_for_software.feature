
Feature: Search for software

  Background:
    Given I am Mike

  @javascript @personas
  Scenario: Finding software according to a search term
    Given there is a software product with the following properties:
      | Product | suchbegriff1 |
      | Manufacturer | suchbegriff4 |
    And there is a software license with the following properties:
      | Inventory code       | suchbegriff2        |
      | Serial number        | suchbegriff3        |
      | Dongle ID            | suchbegriff5        |
      | Quantity allocations | 1 / Christina Meier |
    And this software license is handed over to somebody
    When I search for one of these software product properties
    Then all matching software products appear
    And all matching software licenses appear
    And all contracts containing this software product appear
    When I search for one of these software license properties
    Then all matching software licenses appear
    And all contracts containing this software product appear

  @javascript @personas
  Scenario: Finding contracts for software by searching for a borrower
    Given a software license exists
    And this software license is handed over to somebody
    When I search after the name of that person
    Then the contract of this person appears in the search results
    And this person appears in the search results

  @javascript @personas
  Scenario: How search results are displayed
    Given a software product exists
    And there exist licenses for this software product
    When I see these in my search result
    Then I can select to list only software products
    And I can select to list only software licenses
