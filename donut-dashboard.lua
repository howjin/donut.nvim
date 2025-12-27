-- Animated 3D Donut Dashboard (inspired by donut.c by Andy Sloane)
return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    local A, B = 0, 0
    local timer = nil
    local donut_buf = nil
    local donut_win = nil

    local width, height = 56, 18
    local theta_spacing = 0.07
    local phi_spacing = 0.02
    local chars = ".,-~:;=!*#$@"

    local function render_donut()
      local output = {}
      local zbuffer = {}
      
      -- Initialize buffers
      for y = 1, height do
        output[y] = {}
        zbuffer[y] = {}
        for x = 1, width do
          output[y][x] = " "
          zbuffer[y][x] = 0
        end
      end

      local cosA, sinA = math.cos(A), math.sin(A)
      local cosB, sinB = math.cos(B), math.sin(B)

      local theta = 0
      while theta < 2 * math.pi do
        local costheta, sintheta = math.cos(theta), math.sin(theta)

        local phi = 0
        while phi < 2 * math.pi do
          local cosphi, sinphi = math.cos(phi), math.sin(phi)

          -- 3D coordinates of a point on the torus
          local circlex = 2 + 1 * costheta  -- R2 + R1*cos(theta)
          local circley = 1 * sintheta       -- R1*sin(theta)

          -- 3D rotation
          local x = circlex * (cosB * cosphi + sinA * sinB * sinphi) - circley * cosA * sinB
          local y = circlex * (sinB * cosphi - sinA * cosB * sinphi) + circley * cosA * cosB
          local z = 5 + cosA * circlex * sinphi + sinA * circley  -- K2 + ...
          local ooz = 1 / z

          -- Project to 2D
          local xp = math.floor(width / 2 + 28 * ooz * x)
          local yp = math.floor(height / 2 + 14 * ooz * y)

          -- Calculate luminance
          local L = cosphi * costheta * sinB - cosA * costheta * sinphi - sinA * sintheta + cosB * (cosA * sintheta - costheta * sinA * sinphi)

          if L > 0 and xp >= 1 and xp <= width and yp >= 1 and yp <= height then
            if ooz > zbuffer[yp][xp] then
              zbuffer[yp][xp] = ooz
              local luminance_index = math.floor(L * 8) + 1
              luminance_index = math.max(1, math.min(luminance_index, #chars))
              output[yp][xp] = chars:sub(luminance_index, luminance_index)
            end
          end

          phi = phi + phi_spacing
        end
        theta = theta + theta_spacing
      end

      -- Convert to lines
      local lines = {}
      for y = 1, height do
        lines[y] = table.concat(output[y])
      end
      return lines
    end

    local function start_donut()
      if donut_buf and vim.api.nvim_buf_is_valid(donut_buf) then
        return
      end

      donut_buf = vim.api.nvim_create_buf(false, true)
      vim.bo[donut_buf].bufhidden = "wipe"
      vim.bo[donut_buf].modifiable = true

      local win_width = vim.o.columns

      donut_win = vim.api.nvim_open_win(donut_buf, false, {
        relative = "editor",
        width = width,
        height = height,
        col = math.floor((win_width - width) / 2),
        row = 1,
        style = "minimal",
        border = "none",
        zindex = 1,
        focusable = false,
      })

      -- Make background transparent(i use ghostty)
      vim.api.nvim_set_hl(0, "DonutNormal", { bg = "NONE" })
      vim.wo[donut_win].winhighlight = "Normal:DonutNormal"

      timer = vim.uv.new_timer()
      timer:start(0, 40, vim.schedule_wrap(function()
        if not donut_buf or not vim.api.nvim_buf_is_valid(donut_buf) then
          if timer then
            timer:stop()
            timer:close()
            timer = nil
          end
          return
        end

        local ok, lines = pcall(render_donut)
        if ok and lines then
          pcall(vim.api.nvim_buf_set_lines, donut_buf, 0, -1, false, lines)
        end

        A = A + 0.08
        B = B + 0.04
      end))
    end

    local function stop_donut()
      if timer then
        timer:stop()
        timer:close()
        timer = nil
      end
      if donut_win and vim.api.nvim_win_is_valid(donut_win) then
        pcall(vim.api.nvim_win_close, donut_win, true)
      end
      donut_buf = nil
      donut_win = nil
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "SnacksDashboardOpened",
      callback = start_donut,
    })

    vim.api.nvim_create_autocmd("User", {
      pattern = "SnacksDashboardClosed",
      callback = stop_donut,
    })

    vim.api.nvim_create_autocmd("BufLeave", {
      callback = function()
        if vim.bo.filetype == "snacks_dashboard" then
          stop_donut()
        end
      end,
    })

    opts.dashboard = opts.dashboard or {}
    opts.dashboard.preset = opts.dashboard.preset or {}
    opts.dashboard.preset.header = string.rep("\n", 20)

    return opts
  end,
}
