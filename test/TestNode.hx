import stretch.Style.Display;

class TestNode extends utest.Test {
    function testChildren() {
        var child1 = new Node({}, []);
        var child2 = new Node({}, []);
        var node = new Node({}, [child1, child2]);

        Assert.equals(node.children.length, 2);
        Assert.equals(node.children[0], child1);
        Assert.equals(node.children[1], child2);
    }

    function testSetMeasure() {
        var node = Node.leaf({}, _ -> { width: 200.0, height: 200.0 });
        Stretch.computeLayout(node, Size.undefined());
        Assert.equals(node.layout.size.width, 200.0);

        node.measure = _ -> { width: 100.0, height: 100.0 };
        Stretch.computeLayout(node, Size.undefined());
        Assert.equals(node.layout.size.width, 100.0);
    }

    function testAddChild() {
        var node = new Node({}, []);
        Assert.equals(node.children.length, 0);

        var child1 = new Node({}, []);
        node.addChild(child1);
        Assert.equals(node.children.length, 1);

        var child2 = new Node({}, []);
        node.addChild(child2);
        Assert.equals(node.children.length, 2);
    }

    function testRemoveChild() {
        var child1 = new Node({}, []);
        var child2 = new Node({}, []);

        var node = new Node({}, [child1, child2]);
        Assert.equals(node.children.length, 2);

        node.removeChild(child1);
        Assert.equals(node.children.length, 1);
        Assert.equals(node.children[0], child2);

        node.removeChild(child2);
        Assert.equals(node.children.length, 0);
    }

    function testRemoveChildAtIndex() {
        var child1 = new Node({}, []);
        var child2 = new Node({}, []);

        var node = new Node({}, [child1, child2]);
        Assert.equals(node.children.length, 2);

        node.removeChildAtIndex(0);
        Assert.equals(node.children.length, 1);
        Assert.equals(node.children[0], child2);

        node.removeChildAtIndex(0);
        Assert.equals(node.children.length, 0);
    }

    function testReplaceChildAtIndex() {
        var child1 = new Node({}, []);
        var child2 = new Node({}, []);

        var node = new Node({}, [child1]);
        Assert.equals(node.children.length, 1);
        Assert.equals(node.children[0], child1);

        node.replaceChildAtIndex(0, child2);
        Assert.equals(node.children.length, 1);
        Assert.equals(node.children[0], child2);
    }

    function testSetChildren() {
        var child1 = new Node({}, []);
        var child2 = new Node({}, []);
        var node = new Node({}, [child1, child2]);

        Assert.equals(node.children.length, 2);
        Assert.equals(node.children[0], child1);
        Assert.equals(node.children[1], child2);

        var child3 = new Node({}, []);
        var child4 = new Node({}, []);
        node.setChildren([child3, child4]);

        Assert.equals(node.children.length, 2);
        Assert.equals(node.children[0], child3);
        Assert.equals(node.children[1], child4);
    }

    function testSetStyle() {
        var node = new Node({}, []);
        Assert.equals(node.style.display, Display.Flex);

        node.style = { display: None };
        Assert.equals(node.style.display, Display.None);
    }

    function testMarkDirty() {
        var child1 = new Node({}, []);
        var child2 = new Node({}, []);
        var node = new Node({}, [child1, child2]);

        Stretch.computeLayout(node, Size.undefined());

        Assert.equals(child1.isDirty, false);
        Assert.equals(child2.isDirty, false);
        Assert.equals(node.isDirty, false);

        node.markDirty();
        Assert.equals(child1.isDirty, false);
        Assert.equals(child2.isDirty, false);
        Assert.equals(node.isDirty, true);

        Stretch.computeLayout(node, Size.undefined());
        child1.markDirty();
        Assert.equals(child1.isDirty, true);
        Assert.equals(child2.isDirty, false);
        Assert.equals(node.isDirty, true);
    }
}
