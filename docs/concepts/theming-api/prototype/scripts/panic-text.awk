# Extracts the first error of a failed `typst compile` as ONE line.
# typst 0.15 prints a panic string raw (a multi-line message spans lines up to
# the source excerpt); typst 0.14 prints it quoted, with \n and \" escapes.
# Both become the same line: newlines plus indentation collapse to one space.
/^error:/ && !f {
  f = 1
  sub(/^error: (panicked with: )?/, "")
  if ($0 ~ /^".*"$/) {
    $0 = substr($0, 2, length($0) - 2)
    gsub(/\\n */, " ")
    gsub(/\\"/, "\"")
    gsub(/\\\\/, "\\")
    printf "%s", $0
    exit
  }
  printf "%s", $0
  next
}
f && /^ *([^ -~]|$)/ { exit }
f { sub(/^ +/, ""); printf " %s", $0 }
