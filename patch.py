import re

path = r'C:\Users\mylogical\Projects\New_App\lib\screens\member_shell_screen.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('body: IndexedStack(', 'body: LazyIndexedStack(')

lazy_stack = '''
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  
  const LazyIndexedStack({super.key, required this.index, required this.children});
  
  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late List<bool> _activated;
  
  @override
  void initState() {
    super.initState();
    _activated = List<bool>.filled(widget.children.length, false);
    _activated[widget.index] = true;
  }
  
  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      _activated = List<bool>.filled(widget.children.length, false);
    }
    _activated[widget.index] = true;
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      children: List.generate(widget.children.length, (i) {
        if (!_activated[i]) return const SizedBox.shrink();
        return widget.children[i];
      }),
    );
  }
}
'''

if 'class LazyIndexedStack' not in content:
    content += '\n' + lazy_stack

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Patched successfully')
