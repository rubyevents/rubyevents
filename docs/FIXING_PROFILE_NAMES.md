# Description

Fixing speaker/profile names is a pretty common occurance, and we have a few different strategies for it.

## Duplicate names in Speaker.yml

- De-dupe the speakers.yml - there should be one speaker with a name and GitHub handle.
- Update all talks to use the name of the de-duped speaker.
- Run the seeds on production
- In the admin, after confirming talks are transferred, delete the old speaker
- If the duplicated name is likely to be used again, eg. "Matz", create an alias in the admin.
  - Aliases ensure that urls using the old name are redirected, so RubyEvents strongly encourages their use. 

## Two different GitHub profiles

- Pick one canonical GitHub profile and put it in speakers.yml
- All talks should reference the name from that profile
- Admin should add an alias for the old GitHub profile so it redirects to the new one

## Missing GitHub profile on Speaker - Signed up as user

- Update speakers.yml with the GitHub
- Delete the existing Speaker record in the admin
- Run seeds again

## Updating your name

- Update the name in speakers.yml
- Update all references in the videos.yml and involvements.yml to the new name
- Create an alias from the old name to redirect to the new name
- Admin deletes old profile
