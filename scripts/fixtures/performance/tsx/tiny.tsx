import { NavigationContainer } from '@react-navigation/native';
import { createStackNavigator } from '@react-navigation/stack';
import { StatusBar } from 'expo-status-bar';
import { StyleSheet, Text, View } from 'react-native';
import QRCodeScreen from './src/screens/QRCode';
import ScanScreen from './src/screens/Scan';

const Stack = createStackNavigator();

const Application = () => {
    return (
        <NavigationContainer>
            <Stack.Navigator initialRouteName="QRCode">
                <Stack.Screen name={'QRCode'} component={QRCodeScreen} />
                <Stack.Screen name={'Scan'} component={ScanScreen} />
            </Stack.Navigator>
            <StatusBar style="auto" />
        </NavigationContainer>
    );
};

export default Application;
