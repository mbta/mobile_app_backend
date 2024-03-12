# Mobile App Backend

The backend server supporting our mobile app. Provides data from the V3 API and OpenTripPlanner.

## Development

### Prerequisites

Install the tools specified in `.tool-versions`. You can use [asdf](https://asdf-vm.com/) to help manage the required versions.

### Environment Configuration

Install [direnv](https://direnv.net/) if you don't already have it, copy `.envrc.example` to `.envrc`, populate any required values, then run `direnv allow`.

### Running the application

- Run `mix setup` to install and setup dependencies
- Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

### Running tests

Run command `mix test` to run all tests.

Integration tests use snapshots of data returned by the MBTA V3 API. To update those data snapshots used by a particular test module, run the [UpdateTestData](https://github.com/mbta/mobile_app_backend/blob/main/lib/mix/tasks/update_test_data.ex) mix task with command `mix updateTestData [pathToTestFile]`

### Editing Code

- Create each new feature in its own branch named with the following naming format: initials-description (for example, Jane Smith writing a search function might create a branch called js-search-function).
- This repo uses [pre-commit hooks](https://pre-commit.com/), which will automatically run and update files before committing. Install with `brew install pre-commit` and set up the git hook scripts by running `pre-commit install`.
- Use meaningfully descriptive commit messages to help reviewers understand the changes. Consider following [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0-beta.2/) guidelines.

### Code Review

All new features are required to be reviewed by a team member. Department-wide code review practices can be found [here](https://www.notion.so/mbta-downtown-crossing/Code-Reviews-df7d4d6bb6aa4831a81bc8cef1bebbb5).

Some specifics for this repo:

- Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0-beta.2/) for pull request titles.
- New pull requests will automatically kick off testing and request a review from the [mobile-app-backend team](https://github.com/orgs/mbta/teams/mobile-app-backend). If you aren't yet ready for a review, create a draft PR first.
- When adding commits after an initial review has been performed, avoid force-pushing to help reviewers follow the updated changes.
- Once a PR has been approved and all outstanding comments acknowledged, squash merge it to the main branch.

## Deploying

### Development Deploys

Merging to main will automatically kick off deploys to the staging environment. To trigger a deploy to a particular development environment for testing prior to merge, apply a "deploy to dev-\*" label to a PR.

### Prod Deploys

todo
