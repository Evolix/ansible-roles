# etc-git

Put /etc under Git version control.

## Tasks

The main part (installation and configuration) is in the `tasks/main.yml` file.

There is also an independant task that can be executed to commit changes made in `/etc/.git`, for example when a playbook is run :

```
- name: My Splendid Playbook
  […]

  pre_tasks:
  - include_role:
      name: etc-git
      task_from: commit.yml
    vars:
      commit_message: "Ansible pre-run my splendid playbook"

  roles :
  […]

  post_tasks:
  - include_role:
      name: etc-git
      task_from: commit.yml
    vars:
      commit_message: "Ansible pre-run my splendid playbook"
```
