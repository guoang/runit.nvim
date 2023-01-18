local M = {}

M.project_config = {}
M.ft_config = {
  markdown = { test = ":MarkdownPreview", all = { "#test" } },
  html = { test = ":silent !open ${__file_path__}", all = { "#test" } },
  cpp = {
    build = "c++ -g -std=gnu++2a -I/usr/local/include/ -L/usr/local/lib -o ${__file_name__}.out ${__file_path__}",
    test = "./${__file_name__}.out",
    clean = "rm ${__file_name__}.out",
    all = { "#build", "#test", "#clean" },
  },
  c = {
    build = "cc -g -std=gnu99 -I/usr/local/include/ -L/usr/local/lib -o ${__file_name__}.out ${__file_path__}",
    test = "./${__file_name__}.out",
    clean = "rm ${__file_name__}.out",
    all = { "#build", "#test", "#clean" },
  },
  python = { test = "python3 ${__file_path__}", all = { "#test" } },
  cmake = { test = "cmake -P ${__file_path__}", all = { "#test" } },
  php = { test = "php ${__file_path__}", all = { "#test" } },
  lua = { test = "lua ${__file_path__}", all = { "#test" } },
}

return M
