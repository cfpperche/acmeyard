import { View, Text } from "react-native";

export default function Home() {
  return (
    <View className="flex-1 items-center justify-center bg-background p-md">
      <View className="max-w-md space-y-md">
        <Text className="text-3xl font-semibold text-foreground">PROTOTYPE_SLUG</Text>
        <Text className="text-base text-foreground/80">
          Placeholder home — Phase 3 screen-writer subagents replace this with route-specific content.
        </Text>
      </View>
    </View>
  );
}
