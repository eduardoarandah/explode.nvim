# Explode.nvim 💣 🧨💥

Some things just work better with explosions.

## Installation

### lazy.nvim

```lua
{ "https://github.com/eduardoarandah/explode.nvim" }
```

### vim.pack

```lua
vim.pack.add({"https://github.com/eduardoarandah/explode.nvim"})
```

## Recipes

### :Explode command

Make that code blazingly explosive 💣

```lua
vim.api.nvim_create_user_command("Explode", function()
  require("explode").explode()
end, { desc = "Explode current viewport" })
```

You can change physics parameters, of course

```lua
vim.api.nvim_create_user_command("Explode", function()
  require("explode").explode({
    horizontal_speed = 25.0, -- max random X velocity
    vertical_speed   = 2.0,  -- initial upward burst
    gravity          = 0.1,  -- downward acceleration per tick
    bounce           = 0.5,  -- elasticity on floor collision (0–1)
    friction         = 0.6,  -- horizontal damping on floor (0–1)
  })
end, { desc = "Explode current viewport" })
```

### Git reset hard + explode

Throw that spaghetti code to the trash where it belongs with `:GitResetHardExplode`

```lua
vim.api.nvim_create_user_command("GitResetHardExplode", function()
  vim.fn.system("git reset --hard && git clean -df")
  vim.cmd.edit()
  require("explode").explode()
end, { desc = "git reset --hard and explode" })
```
