Feature: Changing the borrower

  Background:
    Given I am Pius

  @broken
  Scenario: Changing the borrower of a reservation
    Given I am doing a hand over
    Then I can change the borrower for all the reservations I've selected
