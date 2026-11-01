# 截图标注操作区：同类产品一手资料核查

核查日期：2026-11-01。只依据产品官网、官方文档、官方源码 / 开发文档。布局与操作规则分开记录；功能列表没有说明控件位置时不推断位置。

| 产品 | 有证据的交互与位置 | 对 CruxShotter 的启发与限制 |
| --- | --- | --- |
| **Snipaste** | 官方入门指南列出标注阶段的滚轮、`1` / `2` 改笔宽，`Tab` 切换线条 / 箭头，较大的色块按钮打开自定义颜色。其免费版**不能直接重编辑已完成图形**，需撤销再重做；官方 Pro 对照页说明 Pro 才支持在绘图栏选择对应类型后重编辑、不同标注工具分别记住颜色、更多箭头样式。来源：[Getting Started](https://github.com/Snipaste/feedback/wiki/Getting-Started)、[PRO](https://github.com/Snipaste/feedback/wiki/PRO)。 | 快捷键可以代替常驻线宽控件；不同工具记忆属性能减少重复选色。但不能把免费版的“画后编辑”当成我们的参照，Pro 的编辑方式也不等同于直接点击任意对象即可改。官方文字没有足够依据断言其颜色板与箭头样式板一定共处同一位置。 |
| **Shottr** | 官方入门指南明确：点击已有标注对象后，**编辑器右上方**出现小型浮动属性栏，在那里改颜色、尺寸以及视工具而定的样式 / 行为；已有标注可再次选中、移动、缩放。更新记录说新版本画完对象后保持当前工具，便于连续加箭头 / 序号。来源：[Start guide](https://shottr.cc/kb/startguide)、[官方更新记录](https://shottr.cc/newversion.html)。 | “选中对象后显示属性”与“绘制工具保持激活”值得借鉴。但右上属性栏与左侧工具分离，正是当前用户觉得跳跃的形式；不能把 Shottr 描述成属性就地出现在工具旁。 |
| **CleanShot X** | 官网明确有 4 种箭头样式（含曲线）、序号、取色和保存常用色；截图后有 Quick Access Overlay，可在快速保存 / 复制与进入 Annotate 编辑器之间选择；CleanShot 项目文件可保留可编辑标注。来源：[All Features](https://cleanshot.com/features)、[Screenshots](https://cleanshot.com/screenshots)。 | 其“快速处理”与“完整标注”分层可借鉴；多样式需要紧凑呈现。官方功能页**未明确说明箭头样式、颜色控件具体在哪个边或何时展开**，不能据此声称其采用某一种工具卡布局。 |
| **Flameshot** | 官方快捷键文档明确 `Space` 展开 / 收起侧栏，侧栏同时包含当前工具选项、绘图颜色和历史；右键弹色轮，滚轮改工具粗细；`A`、`R` 等键直接选工具。来源：[Key Bindings](https://flameshot.org/docs/guide/key-bindings/)、[官方功能概览](https://flameshot.org/)。 | “工具选项 + 颜色共处一侧栏”有明确先例，也可保持默认界面轻巧。但这是可展开侧栏，不等同于每个工具图标旁独立弹卡；其具体视觉尺寸也不能从文字推出。 |

## 可直接转化的设计判断

1. **把同一操作阶段需要的属性聚合**：Flameshot 的侧栏有直接证据；用户当前抱怨正是工具与样式 / 颜色分散。建议优先评估同位的工具选项区，而非继续保留屏幕另一侧的属性栏。[来源](https://flameshot.org/docs/guide/key-bindings/)
2. **绘制与选中编辑是两种上下文**：Shottr 在对象选中后出现属性栏；Snipaste Pro 需要选择对应类型才能重编辑。我们的界面应明确标示正在设置“新建默认值”还是“所选标注”，避免无声改变两者。[Shottr](https://shottr.cc/kb/startguide)、[Snipaste Pro](https://github.com/Snipaste/feedback/wiki/PRO)
3. **连续绘制和键盘调粗细已有先例**：Shottr 画完保留工具，Snipaste `1` / `2` 和滚轮改笔宽。CruxShotter 已支持这两项，应在新布局中保持。[Shottr](https://shottr.cc/newversion.html)、[Snipaste](https://github.com/Snipaste/feedback/wiki/Getting-Started)
4. **不要把竞品功能清单当作布局证据**：CleanShot 的箭头样式 / 色盘功能已核实，布局尚未核实；因此后续方案中的面板位置应写成我们的设计选择，而不是模仿其现有 UI。[来源](https://cleanshot.com/features)

## 对先前四个交互稿的修正

- “侧边常驻 / 工具板展开”应标为**结合 Flameshot 同侧属性思想与本项目现有左侧工具架的自有方案**，不是 Snipaste / CleanShot 的现成布局。
- “双段工具键”与“角落一体条”目前只是探索性设计，未找到足够一手依据证明上述产品采用相同操作；不应以“竞品都这样做”支持它们。
- 如要借鉴 Shottr，应忠实描述为“选中后右上出现属性栏”，并承认它与用户期望的同位操作存在距离。
