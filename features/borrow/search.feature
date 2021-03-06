
Feature: Search

  Background:
    Given I am Normin

  @rack
  Scenario: Search field
    Given I am listing the main categories
    Then I can see the search box

  Scenario: Show list according to search criteria
    Given I am listing the main categories
    When I enter a search term
    Then I see image, name and manufacturer of the first 6 matching models
    And I see a link labeled 'Show all search results'

  Scenario: Search only for models I can actually borrow
    Given I search for a model that I can't borrow
    Then that model is not shown in the search results

  Scenario: Choosing a suggestion
    Given I am listing the main categories
    And I pick a model from the ones suggested
    Then I see the model's detail page

  Scenario: Displaying search results
    Given I am listing the main categories
    When I enter a search term
    And I press the Enter key
    Then the search result page is shown
    And I see image, name and manufacturer of all matching models
    And I see the sort options
    And I see the inventory pool selector
    And I see filters for start and end date 
    And the suggestions have disappeared

  Scenario: Showing search term with spaces
    Given I am listing the main categories
    When I search for models giving at least two space separated terms
    And I press the Enter key
    Then the search result page is shown
    And I see image, name and manufacturer of all matching models
