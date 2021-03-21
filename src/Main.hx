import stretch.Node;
import stretch.Size;
import stretch.Stretch.computeLayout;

function main() {
	var child = new Node({
		size: {
			width: Percent(0.5),
			height: Auto,
		}
	});

	var node = new Node(
		{
			size: {
				width: Points(100.0),
				height: Points(100.0),
			},
			justifyContent: Center,
		},
		[child]
	);

	node.markDirty();

	computeLayout(node, Size.undefined());
	trace(node.layout);
	trace(child.layout);
}
