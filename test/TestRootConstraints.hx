class TestRootConstraints extends utest.Test {
	function testRootWithPercentageSize() {
        var node = new Node({
			size: {
				width: Percent(1.0),
				height: Percent(1.0),
			}
		});

        Stretch.computeLayout(
			node,
			{ width: Number.defined(100.0), height: Number.defined(200.0) }
		);
        var layout = node.layout;

        Assert.equals(100.0, layout.size.width);
        Assert.equals(200.0, layout.size.height);
    }


    function testRootWithNoSize() {
        var node = new Node({});

        Stretch.computeLayout(
			node,
			{ width: Number.defined(100.0), height: Number.defined(100.0) }
		);
        var layout = node.layout;

        Assert.equals(0.0, layout.size.width);
        Assert.equals(0.0, layout.size.height);
    }

    function testRootWithLargerSize() {
        var node = new Node({
			size: {
				width: Points(200.0),
				height: Points(200.0),
			}
		});

        Stretch.computeLayout(
			node,
			{ width: Number.defined(100.0), height: Number.defined(100.0) }
		);
        var layout = node.layout;

        Assert.equals(200.0, layout.size.width);
        Assert.equals(200.0, layout.size.height);
    }
}
