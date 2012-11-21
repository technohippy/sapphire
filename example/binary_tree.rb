# http://www.perltutorial.org/perl-binary-tree.aspx
def basic_tree_find(tree_link, targe, &cmp)
  node = nil
  while node = tree_link
    relation = nil
    if defined cmp
      relation = cmp.call target, node['val']
    else
      relation = target <=> node['val']
    end
    return [tree_link, node] if relation == 0
    tree_link = relation > 0 ? node['left'].to_ref : node['right'].to_ref
  end
  [tree_link, nil]
end

def basic_tree_add(tree_link, target, &cmp)
  tree_link, found = *basic_tree_find(tree_link, target, &cmp)
  unless found
    found = {
      'left' => nil,
      'right' => nil,
      'val' => target
    }
    tree_link = found
  end
  found
end

def basic_tree_del(tree_link, target, &cmp)
  tree_link, found = *basic_tree_find(tree_link, target, &cmp)
  return nil unless found

  if !defind found['left']
    tree_link = found['right']
  elsif !defind found['right']
    tree_link = found['left']
  else
    merge_somehow tree_link, found
  end
  found['val']
end

def merge_somehow(tree_link, found)
  left_of_right = found['right']
  next_left = nil
  left_of_right = next_left while next_left = left_of_right['left']
  left_of_right['left'] = found['left']
  tree_link = found['right']
end

def traverse(tree, &func)
  return unless tree

  traverse tree['left'], &func
  func.call tree
  traverse tree['right'], &func
end
