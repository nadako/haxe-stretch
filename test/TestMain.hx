function main() {
	utest.UTest.run([
		new TestMeasure(),
		new TestRootConstraints(),
		new TestNode(),
		new TestFixtures(),
	]);
}
