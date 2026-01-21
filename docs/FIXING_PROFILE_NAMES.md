# Description

Fixing speaker/profile names is a pretty common occurance, and we have a few different strategies for it.

## Common Truths

- We use the GitHub profile as a unique identifier throughout the site.
- If the name, slug, or GitHub stays the same, we find and update the existing record.
- Aliases ensure that urls using the old name are redirected, we strongly encourage their use.
- Aliases also ensure future or previous talks being uploaded are associated with the right user.
- Test your changes by running `bundle exec rake db:seed:speakers`.

### Creating an alias

In this example, we set up two aliases for Matz.
All future talks with Matz or Yukihiro 'Matz' Matsumoto will redirect to Yukihiro "Matz" Matsumoto.

```
- name: "Yukihiro \"Matz\" Matsumoto"
  github: "matz"
  slug: "yukihiro-matz-matsumoto"
  aliases:
    - name: "Matz"
      slug: "matz"
    - name: "Yukihiro 'Matz' Matsumoto"
      slug: "yukihiro-matz-matsumoto"
```

## Duplicate names in speakers.yml

If there are two instances of a user in speakers.yml, we create two users.

- De-dupe the /data/speakers.yml - there should be one speaker with a name and GitHub handle.
  - Create an alias in speakers.yml if the duplicated name is likely to be used again.
- Update all talks to use the name of the de-duped speaker.
- After merge:
  - In the admin, delete the old user.
  - Run the seeds on production

## Two different GitHub profiles

- Pick one canonical GitHub profile and put it in speakers.yml
  - Add an alias for the old GitHub profile so it redirects to the new one
- Remove the other speaker
- All talks should reference the name from that profile

## Missing GitHub profile on Speaker - Signed up as user

- Update /data/speakers.yml with the GitHub handle
- Run `bundle exec rake db:seed` to ensure there are no duplicates
- Run seeds again in production

## Updating your name

- Update the name in speakers.yml
- Update all references in the videos.yml and involvements.yml to the new name
- Create an alias from the old name to redirect to the new name
