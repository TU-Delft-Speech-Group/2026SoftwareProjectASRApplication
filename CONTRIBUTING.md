# Contributing

Contributions to this repository are welcomed under the guidelines of (but not limited to) this document. This document has been inspired by the [Angular project][angular]

## Work items
All code contributions must be linked to a GitLab work item (more commonly known as an issue). Before submitting a work item, see if one matching yours already exists. This way we can prevent duplication and keep the discussion centered around a single topic.

If the work item you are submitting refers to a bug, we have to be able to reproduce it. Therefore, the description should contain the steps used to reproduce the bug. Showcasing the bug, for example through screenshots or video, is strongly encouraged.

When creating a work item one should adhere to the following guidelines:
- Write the work item in English.
- Keep the title short, descriptive, and [imperative].
- Ensure the following questions are answered:
  - What is the current situation?
  - Why should this be changed?
  - What changes are necessary?
- Add relevant tags and update these throughout the contribution workflow.
- Assign the relevant parties and any related items.

## Merge requests
Code contributions are submitted and reviewed through merge requests. 

### Creating a merge request
To contribute, create a new branch in your forked repository. Ensure the changes adhere to the coding rules and other guidelines specified in this document. The branch must pass all tests and where appropriate new tests should be added and existing tests may need to be updated. Once these conditions have been satisfied, create a commit which:
- has a short and clear title,
- includes a description of the changes, and
- lists the related issue(s) in the footer prefixed with `Closes` or `Fixes`.

For reference, you may want to check out the [Angular commit message guidelines][angular-commit-message].

### Reviewing a merge request
Every merge request to the `dev` branch has to be approved by at minimum two people with the `developer` role. This ensures that changes have gone through a sufficient review process by a group with expertise in the project. However, if you have relevant and constructive feedback, such as from experience in other projects, please feel free to add to the discussion.

#### Addressing feedback
When changes have been requested through a review, please make the changes and then ensure that all tests still pass. Then create a fixup commit that includes the changes:
```sh
git commit --all --fixup HEAD # create a fixup commit including all changes tracked by Git
git push # update the remote branch
```

It may also be the case that you need to update the original commit message. This may be done as follows:
```sh
git commit --amend # open an editor to update the previous commit
git push --force-with-lease # update the remote branch
```
> note: this way it is also possible to include updates in the original commit, which may keep the commit history clearer.

#### Updating your branch to match dev
Your branch has to be up-to-date with the latest changes on `dev` before it can be merged. Often, this is as easy as using the `rebase` button on the Merge Request page within GitLab. However, it may happen that the changes on dev since your branch was created are in conflict with your changes. In this case you will need to rebase your branch locally, which can be done as follows:
```sh
git fetch origin dev # the remote ('origin' here) used should be up-to-date with this repository.
git rebase origin/dev # pull the changes from dev into the current branch, use the same remote as before
git push --force-with-lease # update the remote branch
```

## Code style
The [Flutter Lint][flutter-lint] determines the basis for our coding style. Any custom configuration on top of this can be found in the [analysis_options.yaml](./analysis_options.yaml) file at the root of this repository. This coding style is automatically enforced by CI.

## Code practices
These following principles promote consistency and aim to reduce technical debt within the codebase.

### Follow the documentation
In general this project aims to follow the architecture, code style, and general recommendations from the official [Flutter documentation][flutter-docs]. When deviating from the documentation, explain what is done different and motivate the choice.

### Write useful comments
In some cases it might be useful to add comments that summarize a piece of code. Explaining what certain lines of code do should, however, be an exception and not the norm. Unlike comments that explain why the code exists, or does something the way it does. Context which can not be inferred from looking at just the code, for example issues with very specific environments, should be written down in a comment.

### Error handling
Errors that are expected should be handled gracefully. How this is done may vary from informing the user through an alert to only logging the event for debug purposes. If an error is not specifically accounted for, and thus not within expectations, it should be not handled as the consequence of ignoring these errors can not be known.

### Magic numbers
The concept of magic numbers or magic variables usually refers to (numeric) constants within your code for which no explanation has been given. These are easily avoided, and should be avoided, by extracting them to a constant with a descriptive name.

### Testing
The codebase includes a variety of test suites to ensure the quality of code which is shipped to the user. More about these particular test suites can be found in this repository's [README](./README.md). In general, the guidelines for writing tests are as follows:
- Unit/widget tests: all logic of which external dependencies can be mocked out should be tested through unit/widget tests.
- Accessibility tests: all UI components should be tested for accessibility compliance.
- Regression tests: all UI states and configurations should be tested for regression on a general set of all supported devices.

Besides these, one should keep in mind the automated tests that run on CI/CD which validates the codebase on a broader scale such as license compliance and vulnerabilities within dependencies.


[angular]: https://github.com/angular/angular
[angular-commit-message]: https://github.com/angular/angular/blob/main/contributing-docs/commit-message-guidelines.md
[flutter-docs]: https://docs.flutter.dev/
[flutter-lint]: https://pub.dev/packages/flutter_lints
[imperative]: https://www.yourdictionary.com/articles/examples-imperative-sentences
[semver]: https://semver.org/
