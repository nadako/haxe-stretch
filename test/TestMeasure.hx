class TestMeasure extends utest.Test {
    function testMeasureRoot() {
        var node = Node.leaf({}, constraint -> {
            width: constraint.width.orElse(100.0),
            height: constraint.height.orElse(100.0),
        });

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(100.0, node.layout.size.width);
        Assert.equals(100.0, node.layout.size.height);
    }

    function testMeasureChild() {
        var child = Node.leaf({}, constraint -> {
            width: constraint.width.orElse(100.0),
            height: constraint.height.orElse(100.0),
        });

        var node = new Node({}, [child]);
        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(100.0, node.layout.size.width);
        Assert.equals(100.0, node.layout.size.height);

        Assert.equals(100.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    function measure_child_constraint() {
        var child = Node.leaf({}, constraint -> {
            width: constraint.width.orElse(100.0),
            height: constraint.height.orElse(100.0),
        });

        var node = new Node(
            {
                size: {
                    width: Points(50.0),
                    height: Auto
                },
            },
            [child]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, node.layout.size.width);
        Assert.equals(100.0, node.layout.size.height);

        Assert.equals(50.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    function testMeasureChildConstraintPaddingParent() {
        var child = Node.leaf({}, constraint -> {
            width: constraint.width.orElse(100.0),
            height: constraint.height.orElse(100.0),
        });

        var node = new Node(
            {
                size: {
                    width: Points(50.0),
                    height: Auto,
                },
                padding: {
                    start: Points(10.0),
                    end: Points(10.0),
                    top: Points(10.0),
                    bottom: Points(10.0),
                }
            },
            [child]
        );
        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, node.layout.size.width);
        Assert.equals(120.0, node.layout.size.height);

        Assert.equals(30.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    function testMeasureChildWithFlexGrow() {
        var child0 = new Node({
            size: {
                width: Points(50.0),
                height: Points(50.0),
            }
        });

        var child1 = Node.leaf(
            { flexGrow: 1.0 },
            constraint -> {
                width: constraint.width.orElse(10.0),
                height: constraint.height.orElse(50.0),
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Auto,
                },
            },
            [child0, child1]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child1.layout.size.width);
        Assert.equals(50.0, child1.layout.size.height);
    }

    function testMeasureChildWithFlexShrink() {
        var child0 = new Node({
            size: {
                width: Points(50.0),
                height: Points(50.0),
            },
            flexShrink: 0.0,
        });

        var child1 = Node.leaf(
            {},
            constraint -> {
                width: constraint.width.orElse(100.0),
                height: constraint.height.orElse(50.0),
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Auto,
                },
            },
            [child0, child1]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child1.layout.size.width);
        Assert.equals(50.0, child1.layout.size.height);
    }

    function testRemeasureChildAfterGrowing() {
        var child0 = new Node({
            size: {
                width: Points(50.0),
                height: Points(50.0),
            }
        });

        var child1 = Node.leaf(
            { flexGrow: 1.0 },
            constraint -> {
                var width = constraint.width.orElse(10.0);
                var height = constraint.height.orElse(width * 2.0);
                { width: width, height: height };
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Auto,
                },
                alignItems: FlexStart,
            },
            [child0, child1]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child1.layout.size.width);
        Assert.equals(100.0, child1.layout.size.height);
    }

    function testRemeasureChildAfterShrinking() {
        var child0 = new Node({
            size: {
                width: Points(50.0),
                height: Points(50.0),
            },
            flexShrink: 0.0
        });

        var child1 = Node.leaf(
            {},
            constraint -> {
                var width = constraint.width.orElse(100.0);
                var height = constraint.height.orElse(width * 2.0);
                { width: width, height: height };
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Auto,
                },
                alignItems: FlexStart
            },
            [child0, child1]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child1.layout.size.width);
        Assert.equals(100.0, child1.layout.size.height);
    }

    function testRemeasureChildAfterStretching() {
        var child = Node.leaf(
            {},
            constraint -> {
                var height = constraint.height.orElse(50.0);
                var width = constraint.width.orElse(height);
                { width: width, height: height }
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Points(100.0),
                }
            },
            [child]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(100.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    function testWidthOverridesMeasure() {
        var child = Node.leaf(
            {
                size: {
                    width: Points(50.0),
                    height: Auto,
                }
            },
            constraint -> {
                width: constraint.width.orElse(100.0),
                height: constraint.height.orElse(100.0),
            }
        );

        var node = new Node({}, [child]);
        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    function testHeightOverridesMeasure() {
        var child = Node.leaf(
            {
                size: {
                    height: Points(50.0),
                    width: Auto,
                }
            },
            constraint -> {
                width: constraint.width.orElse(100.0),
                height: constraint.height.orElse(100.0),
            }
        );

        var node = new Node({}, [child]);
        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(100.0, child.layout.size.width);
        Assert.equals(50.0, child.layout.size.height);
    }

    function testFlexBasisOverridesMeasure() {
        var child0 = new Node({
            flexBasis: Points(50.0),
            flexGrow: 1.0
        });

        var child1 = Node.leaf(
            {
                flexBasis: Points(50.0),
                flexGrow: 1.0
            },
            constraint -> {
                width: constraint.width.orElse(100.0),
                height: constraint.height.orElse(100.0),
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(200.0),
                    height: Points(100.0),
                }
            },
            [child0, child1]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(100.0, child0.layout.size.width);
        Assert.equals(100.0, child0.layout.size.height);
        Assert.equals(100.0, child1.layout.size.width);
        Assert.equals(100.0, child1.layout.size.height);
    }

    function testStretchOverridesMeasure() {
        var child = Node.leaf(
            {},
            constraint -> {
                width: constraint.width.orElse(50.0),
                height: constraint.height.orElse(50.0),
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Points(100.0),
                }
            },
            [child]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    function testMeasureAbsoluteChild() {
        var child = Node.leaf(
            { positionType: Absolute },
            constraint -> {
                width: constraint.width.orElse(50.0),
                height: constraint.height.orElse(50.0),
            }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Points(100.0),
                }
            },
            [child]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(50.0, child.layout.size.width);
        Assert.equals(50.0, child.layout.size.height);
    }

    function testIgnoreInvalidMeasure() {
        var child = Node.leaf(
            { flexGrow: 1.0 },
            _ -> { width: 200.0, height: 200.0 }
        );

        var node = new Node(
            {
                size: {
                    width: Points(100.0),
                    height: Points(100.0),
                }
            },
            [child]
        );

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(100.0, child.layout.size.width);
        Assert.equals(100.0, child.layout.size.height);
    }

    static var NUM_MEASURES = 0;
    function testOnlyMeasureOnce() {
        var grandchild = Node.leaf(
            {},
            constraint -> {
                NUM_MEASURES++;
                {
                    width: constraint.width.orElse(50.0),
                    height: constraint.height.orElse(50.0),
                }
            }
        );

        var child = new Node({}, [grandchild]);

        var node = new Node({}, [child]);
        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(1, NUM_MEASURES);
    }
}
